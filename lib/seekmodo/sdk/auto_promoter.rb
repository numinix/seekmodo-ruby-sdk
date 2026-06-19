# frozen_string_literal: true

require_relative "mode"
require_relative "circuit_breaker"
require_relative "tenant_snapshot"
require_relative "storage/protocols"

module Seekmodo
  module Sdk
    class AutoPromoter
      STATE_KEY = "numinix.seekmodo.fsm_state"
      DEFAULT_PROMOTE_AFTER_SECONDS = 3600
      DEFAULT_DEMOTE_COOLDOWN_SECONDS = 900

      def initialize(
        snapshot,
        breaker,
        cache,
        promote_after_seconds: DEFAULT_PROMOTE_AFTER_SECONDS,
        demote_cooldown_seconds: DEFAULT_DEMOTE_COOLDOWN_SECONDS,
        clock: nil
      )
        @snapshot = snapshot
        @breaker = breaker
        @cache = cache
        @promote_after_seconds = promote_after_seconds
        @demote_cooldown_seconds = demote_cooldown_seconds
        @clock = clock || -> { Time.now.to_i }
      end

      def tick
        config = @snapshot.get
        configured_mode = config.fetch("mode", Mode::OFF).to_s
        auto_promote = config.fetch("auto_promote", true)

        if configured_mode != Mode::ACTIVE
          return result(Mode::OFF, Mode::OFF, "held", "mode is not active; auto-promoter idle")
        end
        unless auto_promote
          return result(Mode::OFF, Mode::OFF, "held", "auto_promote disabled")
        end

        state = load_state
        current = state["current_state"].to_s
        now = @clock.call
        breaker_snapshot = @breaker.snapshot
        breaker_open = breaker_snapshot["state"] == CircuitBreaker::STATE_OPEN

        if breaker_open && current == Mode::ENFORCE
          if now - state["last_transition_at"].to_i < @demote_cooldown_seconds
            return result(current, current, "held", "demote cooldown active")
          end
          write_state(Mode::SHADOW, now)
          return result(current, Mode::SHADOW, "demoted", "breaker open at enforce")
        end

        settled_for = now - state["last_transition_at"].to_i
        if breaker_open
          return result(current, current, "held", "breaker open")
        end
        if settled_for < @promote_after_seconds
          return result(current, current, "held", "settled for #{settled_for}s, need #{@promote_after_seconds}s")
        end

        next_step = next_step_up(current)
        if next_step == current
          return result(current, current, "held", "already at enforce")
        end
        write_state(next_step, now)
        result(current, next_step, "promoted", "breaker closed, settled")
      end

      def current_state
        load_state
      end

      private

      def next_step_up(current)
        if [Mode::OFF, Mode::LEARNING].include?(current)
          return Mode::SHADOW
        end
        return Mode::ENFORCE if current == Mode::SHADOW

        current
      end

      def load_state
        raw = @cache.get(STATE_KEY)
        unless raw.is_a?(Hash)
          now = @clock.call
          return { "current_state" => Mode::SHADOW, "last_transition_at" => now }
        end

        current_raw = raw["current_state"].to_s
        current = Mode.valid?(current_raw) ? current_raw : Mode::SHADOW
        {
          "current_state" => current,
          "last_transition_at" => raw.fetch("last_transition_at", 0).to_i
        }
      end

      def write_state(new_state, transitioned_at)
        @cache.set(
          STATE_KEY,
          {
            "current_state" => Mode.assert_mode(new_state),
            "last_transition_at" => transitioned_at
          },
          86400
        )
      end

      def result(from_state, to_state, action, reason)
        {
          "from" => from_state,
          "to" => to_state,
          "action" => action,
          "reason" => reason
        }
      end
    end
  end
end
