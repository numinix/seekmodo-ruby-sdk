# frozen_string_literal: true

module Seekmodo
  module Sdk
    module Tools
      class Registry
        ADMIN_PREFIXES = %w[
          synonyms. pins. ltr. analytics. tenant. merchandising. experiments.
          catalog. queries. segments. banners. deboosts. esp. regions.
          recommendations. bundles. image_search. bot_check. schema.
        ].freeze

        ADMIN_TOOLS = %w[
          synonyms.list synonyms.add synonyms.remove
          pins.list pins.set pins.remove
          ltr.status ltr.retrain ltr.toggle ltr.config.set
          analytics.top_queries analytics.zero_results
          tenant.snapshot tenant.config tenant.config.set
        ].freeze

        def initialize(connector: nil, admin: nil, tenant_id: nil)
          @connector = connector
          @admin = admin
          @tenant_id = tenant_id
        end

        def call(tool, args = {}, tenant_id: @tenant_id)
          normalized = normalize_tool(tool)
          if admin_tool?(normalized)
            unless @admin
              raise ArgumentError, "Admin client required for tool #{normalized}"
            end
            unless tenant_id
              raise ArgumentError, "tenant_id required for admin tool #{normalized}"
            end
            return @admin.call(normalized, args, tenant_id: tenant_id)
          end

          unless @connector
            raise ArgumentError, "Connector client required for tool #{normalized}"
          end

          route_connector(normalized, args)
        end

        private

        def normalize_tool(tool)
          tool.to_s.tr("_", ".")
        end

        def admin_tool?(tool)
          return true if ADMIN_TOOLS.include?(tool)
          return true if tool.start_with?("admin.")

          ADMIN_PREFIXES.any? { |prefix| tool.start_with?(prefix) }
        end

        def route_connector(tool, args)
          case tool
          when "search"
            @connector.search(args)
          when "index"
            documents = args["documents"] || args[:documents] || []
            action = args["action"] || args[:action] || "upsert"
            @connector.index(documents, action: action)
          when "events"
            events = args["events"] || args[:events] || []
            @connector.events(events)
          when "tenant.handshake"
            @connector.tenant_handshake
          when "tenant.snapshot"
            @connector.tenant_snapshot
          when "tenants/token"
            audience = args["audience"] || args[:audience]
            @connector.browser_token(audience)
          when "tools"
            @connector.tools
          when "health"
            @connector.health
          else
            @connector.post_json("/v1/#{tool}", args)
          end
        end
      end
    end
  end
end
