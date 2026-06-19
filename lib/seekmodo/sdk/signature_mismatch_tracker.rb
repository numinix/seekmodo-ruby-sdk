# frozen_string_literal: true

require_relative "../storage/protocols"

module Seekmodo
  module Sdk
    class SignatureMismatchTracker
      CACHE_KEY = "numinix.seekmodo.sigmismatch_failures"
      DEFAULT_WINDOW_SECONDS = 300
      DEFAULT_THRESHOLD = 3

      def initialize(cache, window_seconds: DEFAULT_WINDOW_SECONDS, threshold: DEFAULT_THRESHOLD, clock: nil)
        @cache = cache
        @window_seconds = window_seconds
        @threshold = threshold
        @clock = clock || -> { Time.now.to_i }
      end

      def record_failure
        now = @clock.call
        rows = load_and_prune(now)
        rows << now
        @cache.set(CACHE_KEY, rows, [@window_seconds * 2, 60].max)
      end

      def clear
        @cache.delete(CACHE_KEY)
      end

      def tripped?
        load_and_prune(@clock.call).length >= @threshold
      end

      def failures_in_window
        load_and_prune(@clock.call).length
      end

      private

      def load_and_prune(now)
        cutoff = now - @window_seconds
        stored = @cache.get(CACHE_KEY, [])
        stored = [] unless stored.is_a?(Array)
        pruned = stored.select { |ts| ts.is_a?(Numeric) && ts.to_i >= cutoff }.map(&:to_i)
        if pruned.length != stored.length
          @cache.set(CACHE_KEY, pruned, [@window_seconds * 2, 60].max)
        end
        pruned
      end
    end
  end
end
