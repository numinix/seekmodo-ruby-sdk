# frozen_string_literal: true

require_relative "connector/client"
require_relative "storage/protocols"

module Seekmodo
  module Sdk
    class TenantSnapshot
      DEFAULT_TTL_SECONDS = 300
      DEFAULT_STALE_TTL_SECONDS = 60
      CACHE_KEY = "numinix.seekmodo.tenant_snapshot"
      CACHE_KEY_FETCHED_AT = "numinix.seekmodo.tenant_snapshot.fetched_at"

      def initialize(
        client,
        cache,
        ttl_seconds: DEFAULT_TTL_SECONDS,
        stale_after_seconds: DEFAULT_STALE_TTL_SECONDS,
        clock: nil
      )
        @client = client
        @cache = cache
        @ttl_seconds = ttl_seconds
        @stale_after_seconds = [stale_after_seconds, ttl_seconds].min
        @clock = clock || -> { Time.now.to_i }
      end

      def get
        cached = @cache.get(CACHE_KEY)
        fetched_at = @cache.get(CACHE_KEY_FETCHED_AT, 0).to_i

        if cached.is_a?(Hash) && fetched_at > 0
          age = @clock.call - fetched_at
          if age < @stale_after_seconds
            return cached
          end

          begin
            return refresh
          rescue StandardError
            return cached
          end
        end

        begin
          refresh
        rescue StandardError
          {}
        end
      end

      def refresh
        snapshot = @client.tenant_snapshot
        @cache.set(CACHE_KEY, snapshot, @ttl_seconds)
        @cache.set(CACHE_KEY_FETCHED_AT, @clock.call, @ttl_seconds)
        snapshot
      end

      def forget
        @cache.delete(CACHE_KEY)
        @cache.delete(CACHE_KEY_FETCHED_AT)
      end
    end
  end
end
