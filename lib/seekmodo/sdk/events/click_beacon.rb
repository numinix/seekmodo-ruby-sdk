# frozen_string_literal: true

module Seekmodo
  module Sdk
    module Events
      module ClickBeacon
        SURFACE_SERP = "serp"
        SURFACE_TYPEAHEAD = "typeahead"
        SURFACE_RECOMMENDATIONS = "recommendations"

        module_function

        def click(query, doc_id, position, is_bot, surface: SURFACE_SERP, shopper_context: nil, extra: nil)
          event = {
            "type" => "click",
            "q" => query,
            "doc_id" => doc_id,
            "position" => position,
            "is_bot" => is_bot,
            "surface" => surface,
            "ts" => Time.now.to_i
          }
          event["shopper"] = shopper_context if shopper_context
          event.merge!(extra) if extra
          event
        end

        def impression(query, doc_ids, is_bot, surface: SURFACE_SERP, shopper_context: nil, extra: nil)
          event = {
            "type" => "impression",
            "q" => query,
            "doc_ids" => doc_ids.dup,
            "is_bot" => is_bot,
            "surface" => surface,
            "ts" => Time.now.to_i
          }
          event["shopper"] = shopper_context if shopper_context
          event.merge!(extra) if extra
          event
        end

        def search(query, hits, is_bot, shopper_context: nil, extra: nil)
          event = {
            "type" => "search",
            "q" => query,
            "hits" => hits,
            "is_bot" => is_bot,
            "surface" => SURFACE_SERP,
            "ts" => Time.now.to_i
          }
          event["shopper"] = shopper_context if shopper_context
          event.merge!(extra) if extra
          event
        end
      end
    end
  end
end
