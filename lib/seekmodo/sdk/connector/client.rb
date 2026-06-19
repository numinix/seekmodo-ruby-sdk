# frozen_string_literal: true

require "json"
require "faraday"

require_relative "../exceptions/client_error"
require_relative "../exceptions/over_quota_error"
require_relative "../exceptions/signature_mismatch_error"
require_relative "../exceptions/tenant_unavailable_error"
require_relative "../hmac_signer"
require_relative "../circuit_breaker"

module Seekmodo
  module Sdk
    module Connector
      class Client
        DEFAULT_GATEWAY_URL = "https://mcp.seekmodo.com"
        INDEX_CHUNK_SIZE = 500
        INDEX_HARD_CAP_PER_CALL = 1000
        DEFAULT_REQUEST_TIMEOUT_MS = 1500
        DEFAULT_CONNECT_TIMEOUT_MS = 250

        attr_reader :signer, :gateway_url

        def initialize(
          signer,
          gateway_url: DEFAULT_GATEWAY_URL,
          breaker: nil,
          user_agent: "seekmodo-ruby-sdk/0.5.0",
          storefront_host: "",
          connection: nil,
          timeout_ms: DEFAULT_REQUEST_TIMEOUT_MS,
          connect_timeout_ms: DEFAULT_CONNECT_TIMEOUT_MS
        )
          @signer = signer
          @gateway_url = gateway_url.to_s.delete_suffix("/")
          @breaker = breaker
          @user_agent = user_agent
          @storefront_host = storefront_host.to_s.downcase.strip
          @owns_connection = connection.nil?
          @connection = connection || build_connection(timeout_ms, connect_timeout_ms)
        end

        def close
          @connection.close if @owns_connection && @connection.respond_to?(:close)
        end

        def search(params)
          post_json("/v1/search", params)
        end

        def index(documents, action: "upsert")
          if documents.length > INDEX_HARD_CAP_PER_CALL
            merged = { "ok" => true, "imported" => 0, "errors" => [] }
            documents.each_slice(INDEX_CHUNK_SIZE) do |chunk|
              res = post_json("/v1/index", { "documents" => chunk, "action" => action })
              merged["imported"] += res.fetch("imported", 0).to_i
              errors = res["errors"]
              merged["errors"] = merged["errors"] + errors if errors.is_a?(Array)
              merged["ok"] = false unless res.fetch("ok", true)
            end
            return merged
          end

          post_json("/v1/index", { "documents" => documents, "action" => action })
        end

        def events(events)
          post_json("/v1/events", { "events" => events })
        end

        def tenant_handshake
          post_json("/v1/tenant/handshake", {})
        end

        def tenant_snapshot
          post_json("/v1/tenant.snapshot", {})
        end

        def browser_token(audience = nil)
          body = audience.nil? ? {} : { "audience" => audience }
          post_json("/v1/tenants/token", body)
        end

        def tools
          get_json("/v1/tools")
        end

        def health
          get_json("/v1/health", signed: false)
        end

        def post_json(path, body, extra_headers = {})
          raw = encode_body(body)
          execute("POST", path, raw, extra_headers, signed: true)
        end

        def get_json(path, extra_headers = {}, signed: true)
          execute("GET", path, "", extra_headers, signed: signed)
        end

        private

        def build_connection(timeout_ms, connect_timeout_ms)
          Faraday.new do |f|
            f.options.timeout = timeout_ms / 1000.0
            f.options.open_timeout = connect_timeout_ms / 1000.0
            f.adapter Faraday.default_adapter
          end
        end

        def execute(method, path, body, extra_headers, signed:)
          if signed && !@signer.configured?
            raise ClientError.new(
              "Seekmodo client is missing tenant_id or shared_secret; cannot sign request.",
              ClientError::KIND_NOT_CONFIGURED
            )
          end
          if @breaker && !@breaker.allow_request?
            raise ClientError.new(
              "Seekmodo circuit breaker is open; refusing to call gateway.",
              ClientError::KIND_BREAKER_OPEN
            )
          end

          headers = {
            "Accept" => "application/json",
            "User-Agent" => @user_agent
          }
          headers["Content-Type"] = "application/json" if body && !body.empty?
          if signed
            headers.merge!(@signer.headers(body))
            if !@storefront_host.empty?
              headers[HmacSigner::HEADER_STOREFRONT_HOST] = @storefront_host
            end
          end
          headers.merge!(extra_headers)

          begin
            response = @connection.run_request(
              method.downcase.to_sym,
              @gateway_url + path,
              body.empty? ? nil : body,
              headers
            )
          rescue Faraday::TimeoutError => e
            on_failure
            raise ClientError.new(
              "Network failure calling Seekmodo gateway: #{e.message}",
              ClientError::KIND_TIMEOUT,
              cause: e
            )
          rescue Faraday::Error => e
            on_failure
            raise ClientError.new(
              "Network failure calling Seekmodo gateway: #{e.message}",
              ClientError::KIND_NETWORK,
              cause: e
            )
          end

          classify(response)
        end

        def classify(response)
          status = response.status
          body = {}
          if response.body && !response.body.to_s.empty?
            decoded = JSON.parse(response.body)
            body = decoded if decoded.is_a?(Hash)
          end

          if status >= 200 && status < 300
            on_success
            return body
          end

          error_code = body["error"].is_a?(String) ? body["error"] : nil
          kind = ClientError.classify_error_code(error_code)

          if status >= 500
            on_failure
            raise ClientError.new(
              "Gateway returned HTTP #{status}",
              ClientError::KIND_HTTP_5XX,
              status,
              body: body
            )
          end

          if kind == ClientError::KIND_TENANT_UNAVAILABLE
            on_success
            raise TenantUnavailableError.new(
              "Tenant unavailable (gateway HTTP #{status}, code=#{error_code})",
              kind,
              status,
              body: body
            )
          end

          if kind == ClientError::KIND_OVER_QUOTA || status == 402
            on_success
            raise OverQuotaError.new(
              "Over plan quota (gateway HTTP #{status}, code=#{error_code || 'over_quota'})",
              ClientError::KIND_OVER_QUOTA,
              status,
              body: body
            )
          end

          if kind == ClientError::KIND_SIGNATURE_MISMATCH || status == 401
            on_failure
            raise SignatureMismatchError.new(
              "Gateway rejected HMAC (HTTP #{status}, code=#{error_code || 'signature_mismatch'})",
              ClientError::KIND_SIGNATURE_MISMATCH,
              status,
              body: body
            )
          end

          on_failure
          raise ClientError.new(
            "Gateway returned HTTP #{status}",
            ClientError::KIND_HTTP_4XX,
            status,
            body: body
          )
        end

        def on_success
          @breaker&.record_success
        end

        def on_failure
          @breaker&.record_failure
        end

        def encode_body(body)
          JSON.generate(body)
        rescue JSON::GeneratorError, TypeError => e
          raise ClientError.new(
            "Failed to JSON-encode request body: #{e.message}",
            ClientError::KIND_BAD_RESPONSE,
            cause: e
          )
        end
      end
    end
  end
end
