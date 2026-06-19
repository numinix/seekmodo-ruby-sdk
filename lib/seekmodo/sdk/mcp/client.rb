# frozen_string_literal: true

require "json"
require "faraday"

require_relative "../exceptions/seekmodo_error"
require_relative "../hmac_signer"

module Seekmodo
  module Sdk
    module Mcp
      class Client
        DEFAULT_GATEWAY_URL = "https://mcp.seekmodo.com"

        def initialize(
          gateway_url: DEFAULT_GATEWAY_URL,
          signer: nil,
          operator_token: nil,
          tenant_id: nil,
          connection: nil,
          user_agent: "seekmodo-ruby-sdk/0.5.0"
        )
          @gateway_url = gateway_url.to_s.delete_suffix("/")
          @signer = signer
          @operator_token = operator_token
          @tenant_id = tenant_id
          @user_agent = user_agent
          @connection = connection || Faraday.new do |f|
            f.adapter Faraday.default_adapter
          end
          @request_id = 0

          if @signer.nil? && @operator_token.nil?
            raise ArgumentError, "MCP client requires signer (HMAC) or operator_token (bearer)"
          end
        end

        def initialize_session(params = {})
          rpc("initialize", params)
        end

        def tools_list
          rpc("tools/list", {})
        end

        def tools_call(name, arguments = {})
          rpc("tools/call", { "name" => name, "arguments" => arguments })
        end

        def ping
          rpc("ping", {})
        end

        private

        def rpc(method, params)
          @request_id += 1
          envelope = {
            "jsonrpc" => "2.0",
            "id" => @request_id,
            "method" => method,
            "params" => params
          }
          body = JSON.generate(envelope)
          response = @connection.post(@gateway_url + "/mcp") do |req|
            req.headers.update(build_headers(body))
            req.body = body
          end

          parsed = JSON.parse(response.body)
          unless response.status >= 200 && response.status < 300
            raise SeekmodoError, "MCP gateway returned HTTP #{response.status}: #{response.body}"
          end

          if parsed["error"]
            raise SeekmodoError, "MCP error #{parsed['error']}"
          end

          parsed["result"]
        rescue JSON::ParserError => e
          raise SeekmodoError, "MCP response was not valid JSON: #{e.message}"
        end

        def build_headers(body)
          headers = {
            "Content-Type" => "application/json",
            "Accept" => "application/json",
            "User-Agent" => @user_agent
          }

          if @operator_token
            headers["Authorization"] = "Bearer #{@operator_token}"
            if @tenant_id
              headers[HmacSigner::HEADER_TENANT] = @tenant_id
            end
          elsif @signer
            headers.merge!(@signer.headers(body))
          end

          headers
        end
      end
    end
  end
end
