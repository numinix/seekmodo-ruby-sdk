# frozen_string_literal: true

require "json"
require "faraday"

module Seekmodo
  module Sdk
    module Admin
      class Error < StandardError
        attr_reader :status, :body

        def initialize(status, body)
          @status = status
          @body = body
          super("gateway #{status}: #{body.to_s[0, 200]}")
        end
      end

      class Client
        DEFAULT_GATEWAY_URL = "https://mcp.seekmodo.com"

        def initialize(admin_key:, gateway_url: DEFAULT_GATEWAY_URL, connection: nil, user_agent: "Seekmodo-Admin/1.0")
          @admin_key = admin_key
          @gateway_url = gateway_url.to_s.delete_suffix("/")
          @user_agent = user_agent
          @connection = connection || Faraday.new do |f|
            f.adapter Faraday.default_adapter
          end
        end

        def call(tool, body, tenant_id:)
          path = tool.start_with?("/") ? tool : "/v1/admin/#{normalize_tool(tool)}"
          call_rest(path, body.merge("tenant_id" => tenant_id), tenant_id: tenant_id)
        end

        def list_synonyms(tenant_id)
          result = call("synonyms.list", {}, tenant_id: tenant_id)
          result.fetch("synonyms", [])
        end

        def add_synonym(tenant_id, body)
          call("synonyms.add", body, tenant_id: tenant_id)
        end

        def remove_synonym(tenant_id, id)
          call("synonyms.remove", { "id" => id }, tenant_id: tenant_id)
        end

        def list_pins(tenant_id)
          result = call("pins.list", {}, tenant_id: tenant_id)
          result.fetch("pins", [])
        end

        def set_pins(tenant_id, body)
          call("pins.set", body, tenant_id: tenant_id)
        end

        def ltr_status(tenant_id, history_limit: nil, history_offset: nil)
          params = {}
          if history_limit
            params["history_limit"] = [[history_limit, 1].max, 50].min
          end
          if history_offset
            params["history_offset"] = [[history_offset, 0].max, 10_000].min
          end
          call("ltr.status", params, tenant_id: tenant_id)
        end

        def ltr_retrain(tenant_id)
          call("ltr.retrain", {}, tenant_id: tenant_id)
        end

        def analytics_top_queries(tenant_id, window: "7d", limit: 20)
          result = call(
            "analytics.top_queries",
            { "window" => window, "limit" => limit },
            tenant_id: tenant_id
          )
          result.fetch("rows", [])
        end

        def analytics_zero_results(tenant_id, window: "7d", limit: 20)
          result = call(
            "analytics.zero_results",
            { "window" => window, "limit" => limit },
            tenant_id: tenant_id
          )
          result.fetch("rows", [])
        end

        private

        def call_rest(path, body, tenant_id:)
          response = @connection.post(@gateway_url + path) do |req|
            req.headers.update(
              "Content-Type" => "application/json",
              "X-Seekmodo-Admin-Key" => @admin_key,
              "X-Seekmodo-Tenant" => tenant_id,
              "User-Agent" => @user_agent
            )
            req.body = JSON.generate(body)
          end

          text = response.body.to_s
          unless response.status >= 200 && response.status < 300
            raise Error.new(response.status, text)
          end

          text.empty? ? nil : JSON.parse(text)
        rescue JSON::ParserError => e
          raise Error.new(response.status, "invalid JSON: #{e.message}")
        end

        def normalize_tool(tool)
          tool.to_s.tr("_", ".")
        end
      end
    end
  end
end
