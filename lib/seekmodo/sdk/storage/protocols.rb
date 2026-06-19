# frozen_string_literal: true

module Seekmodo
  module Sdk
    module Storage
      module Protocols
        module Cache
          def get(key, default = nil)
            raise NotImplementedError
          end

          def set(key, value, ttl_seconds)
            raise NotImplementedError
          end

          def delete(key)
            raise NotImplementedError
          end
        end

        module BreakerStateStore
          def load(key)
            raise NotImplementedError
          end

          def save(key, state, ttl_seconds)
            raise NotImplementedError
          end
        end

        module EventQueueStore
          def push(event)
            raise NotImplementedError
          end

          def drain(max_events)
            raise NotImplementedError
          end

          def count
            raise NotImplementedError
          end
        end
      end
    end
  end
end
