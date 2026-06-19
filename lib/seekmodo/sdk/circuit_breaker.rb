# frozen_string_literal: true

require_relative "storage/protocols"

module Seekmodo
  module Sdk
    class CircuitBreaker
      STATE_CLOSED = "closed"
      STATE_OPEN = "open"
      STATE_HALFOPEN = "half_open"

      def initialize(
        store,
        key: "numinix.seekmodo.circuit",
        failure_threshold: 5,
        failure_window_seconds: 60,
        open_cooldown_seconds: 30,
        clock: nil
      )
        @store = store
        @key = key
        @failure_threshold = failure_threshold
        @failure_window_seconds = failure_window_seconds
        @open_cooldown_seconds = open_cooldown_seconds
        @clock = clock || -> { Time.now.to_i }
      end

      def allow_request?
        state = load_state
        now = @clock.call

        if state["state"] == STATE_OPEN
          if now - state["opened_at"].to_i >= @open_cooldown_seconds
            state["state"] = STATE_HALFOPEN
            state["probe_in_flight"] = true
            save_state(state)
            return true
          end
          return false
        end

        if state["state"] == STATE_HALFOPEN
          return false if state["probe_in_flight"]

          state["probe_in_flight"] = true
          save_state(state)
          return true
        end

        true
      end

      def record_success
        state = load_state
        if [STATE_HALFOPEN, STATE_OPEN].include?(state["state"])
          save_state(
            "state" => STATE_CLOSED,
            "failures" => [],
            "opened_at" => 0,
            "probe_in_flight" => false
          )
          return
        end

        if state["failures"].any?
          state["failures"] = []
          save_state(state)
        end
      end

      def record_failure
        state = load_state
        now = @clock.call

        if state["state"] == STATE_HALFOPEN
          save_state(
            "state" => STATE_OPEN,
            "failures" => [],
            "opened_at" => now,
            "probe_in_flight" => false
          )
          return
        end

        failures = state["failures"] + [now]
        cutoff = now - @failure_window_seconds
        failures = failures.select { |ts| ts >= cutoff }

        if failures.length >= @failure_threshold
          save_state(
            "state" => STATE_OPEN,
            "failures" => [],
            "opened_at" => now,
            "probe_in_flight" => false
          )
          return
        end

        state["failures"] = failures
        save_state(state)
      end

      def state
        load_state["state"]
      end

      def snapshot
        load_state
      end

      private

      def load_state
        @store.load(@key)
      end

      def save_state(state)
        ttl = [@open_cooldown_seconds * 2, @failure_window_seconds * 4].max
        @store.save(@key, state, ttl)
      end
    end
  end
end
