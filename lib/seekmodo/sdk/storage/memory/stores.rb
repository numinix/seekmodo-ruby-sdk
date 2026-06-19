# frozen_string_literal: true

require_relative "../protocols"

module Seekmodo
  module Sdk
    module Storage
      module Memory
        DEFAULT_BREAKER_STATE = {
          "state" => "closed",
          "failures" => [],
          "opened_at" => 0,
          "probe_in_flight" => false
        }.freeze

        class BreakerStore
          include Protocols::BreakerStateStore

          def initialize
            @rows = {}
          end

          def load(key)
            state = @rows[key]
            return DEFAULT_BREAKER_STATE.dup unless state

            {
              "state" => state["state"],
              "failures" => state["failures"].dup,
              "opened_at" => state["opened_at"].to_i,
              "probe_in_flight" => state["probe_in_flight"]
            }
          end

          def save(key, state, ttl_seconds)
            @rows[key] = {
              "state" => state["state"],
              "failures" => state["failures"].dup,
              "opened_at" => state["opened_at"].to_i,
              "probe_in_flight" => state["probe_in_flight"]
            }
          end
        end

        class Cache
          include Protocols::Cache

          Entry = Struct.new(:value, :expires_at, keyword_init: true)

          def initialize(clock = nil)
            @rows = {}
            @clock = clock || -> { Time.now.to_f }
          end

          def get(key, default = nil)
            entry = @rows[key]
            return default unless entry

            if entry.expires_at < @clock.call
              @rows.delete(key)
              return default
            end

            entry.value
          end

          def set(key, value, ttl_seconds)
            @rows[key] = Entry.new(value: value, expires_at: @clock.call + ttl_seconds)
          end

          def delete(key)
            @rows.delete(key)
          end
        end

        class EventQueueStore
          include Protocols::EventQueueStore

          def initialize
            @events = []
          end

          def push(event)
            @events << event.dup
          end

          def drain(max_events)
            batch = @events.take(max_events)
            @events = @events.drop(max_events)
            batch
          end

          def count
            @events.length
          end
        end
      end
    end
  end
end
