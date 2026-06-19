# frozen_string_literal: true

require_relative "../../connector/client"
require_relative "../../storage/protocols"

module Seekmodo
  module Sdk
    module Events
      class EventsQueue
        DEFAULT_AUTO_FLUSH_THRESHOLD = 50
        DEFAULT_MAX_PER_FLUSH = 200

        def initialize(
          client,
          store,
          auto_flush_threshold: DEFAULT_AUTO_FLUSH_THRESHOLD,
          max_per_flush: DEFAULT_MAX_PER_FLUSH
        )
          @client = client
          @store = store
          @auto_flush_threshold = auto_flush_threshold
          @max_per_flush = max_per_flush
        end

        def push(event)
          @store.push(event)
          flush if @store.count >= @auto_flush_threshold
        end

        def flush
          batch = @store.drain(@max_per_flush)
          return 0 if batch.empty?

          begin
            @client.events(batch)
          rescue StandardError
            batch.each { |event| @store.push(event) }
            return 0
          end

          batch.length
        end

        def pending_count
          @store.count
        end
      end
    end
  end
end
