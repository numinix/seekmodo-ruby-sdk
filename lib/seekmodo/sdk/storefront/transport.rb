# frozen_string_literal: true

require "json"
require "faraday"

module Seekmodo
  module Sdk
    module Storefront
      class Transport
        DEFAULT_BASE_URL = "https://gateway.seekmodo.com"
        DEFAULT_TIMEOUT_MS = 8000

        def initialize(
          tenant_id:,
          get_token:,
          base_url: DEFAULT_BASE_URL,
          connection: nil,
          timeout_ms: DEFAULT_TIMEOUT_MS,
          signal: nil,
          on_error: nil,
          get_region: nil,
          user_agent: "seekmodo-ruby-sdk/0.5.0"
        )
          raise ArgumentError, "Seekmodo SDK: tenant_id is required" if tenant_id.to_s.empty?
          raise ArgumentError, "Seekmodo SDK: get_token callback is required" unless get_token.respond_to?(:call)

          @tenant_id = tenant_id
          @get_token = get_token
          @base_url = base_url.to_s.delete_suffix("/")
          @timeout_ms = timeout_ms
          @signal = signal
          @on_error = on_error
          @get_region = get_region
          @user_agent = user_agent
          @cached_token = nil
          @owns_connection = connection.nil?
          @connection = connection || Faraday.new do |f|
            f.options.timeout = timeout_ms / 1000.0
            f.adapter Faraday.default_adapter
          end
        end

        def clear_token_cache
          @cached_token = nil
        end

        def call(tool, args = {}, opts = {})
          begin
            call_once(tool, args, opts, false)
          rescue AuthError => e
            clear_token_cache
            begin
              call_once(tool, args, opts, true)
            rescue StandardError => retry_err
              @on_error&.call(retry_err, tool: tool)
              raise retry_err
            end
          rescue StandardError => e
            @on_error&.call(e, tool: tool)
            raise e
          end
        end

        private

        def call_once(tool, args, opts, is_retry)
          token = resolve_token(is_retry)
          url = "#{@base_url}/v1/#{Faraday::Utils.escape(tool)}"
          headers = {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{token}",
            "X-Seekmodo-Tenant" => @tenant_id,
            "X-Seekmodo-SDK" => @user_agent,
            "User-Agent" => @user_agent
          }

          if @get_region
            begin
              slug = @get_region.call
              headers["Seekmodo-Region"] = slug if slug.is_a?(String) && !slug.empty?
            rescue StandardError
              # ignore misconfigured region hook
            end
          end

          timeout_ms = opts[:timeout_ms] || @timeout_ms
          response = @connection.post(url) do |req|
            req.headers.update(headers)
            req.body = JSON.generate(args)
            req.options.timeout = timeout_ms / 1000.0
          end

          body = response.body.to_s.empty? ? nil : safe_json(response.body)

          if [401, 403].include?(response.status)
            raise AuthError.new(response.status, body, tool)
          end
          if response.status == 402
            raise QuotaError.new(body, tool)
          end
          if response.status >= 500
            raise ServerError.new(response.status, body, tool)
          end
          unless response.status >= 200 && response.status < 300
            raise RequestError.new(response.status, body, tool)
          end

          body
        rescue Faraday::Error => e
          raise NetworkError.new(e, tool)
        end

        def resolve_token(force_refresh)
          now_ms = (Time.now.to_f * 1000).to_i
          if !force_refresh && @cached_token && @cached_token[:expires_at] - 10_000 > now_ms
            return @cached_token[:token]
          end

          result = @get_token.call
          if result.is_a?(String)
            @cached_token = { token: result, expires_at: now_ms + 60_000 }
            return result
          end

          if result.is_a?(Hash) && result["token"].is_a?(String) && result["expires_at"].is_a?(Numeric)
            @cached_token = { token: result["token"], expires_at: result["expires_at"].to_i }
            return result["token"]
          end

          raise ArgumentError, "Seekmodo SDK: get_token must return a string or { token, expires_at }"
        end

        def safe_json(text)
          JSON.parse(text)
        rescue JSON::ParserError
          text
        end

        class Error < StandardError
          attr_reader :tool

          def initialize(tool)
            @tool = tool
            super()
          end
        end

        class AuthError < Error
          attr_reader :status, :body

          def initialize(status, body, tool)
            @status = status
            @body = body
            super(tool)
          end
        end

        class QuotaError < Error
          attr_reader :body

          def initialize(body, tool)
            @body = body
            super(tool)
          end
        end

        class ServerError < Error
          attr_reader :status, :body

          def initialize(status, body, tool)
            @status = status
            @body = body
            super(tool)
          end
        end

        class RequestError < Error
          attr_reader :status, :body

          def initialize(status, body, tool)
            @status = status
            @body = body
            super(tool)
          end
        end

        class NetworkError < Error
          attr_reader :cause

          def initialize(cause, tool)
            @cause = cause
            super(tool)
          end
        end
      end
    end
  end
end
