# frozen_string_literal: true

require_relative "mode"
require_relative "circuit_breaker"
require_relative "tenant_snapshot"

module Seekmodo
  module Sdk
    class ModeFsm
      def initialize(snapshot, breaker: nil, default_mode: Mode::OFF)
        @snapshot = snapshot
        @breaker = breaker
        @default_mode = Mode.assert_mode(default_mode)
      end

      def effective_mode
        if @breaker && @breaker.state == CircuitBreaker::STATE_OPEN
          return Mode::OFF
        end

        config = @snapshot.get
        configured = config.fetch("mode", @default_mode).to_s
        return @default_mode unless Mode.valid?(configured)

        if configured != Mode::ACTIVE
          return configured
        end

        fsm_state = config.dig("fsm", "current_state").to_s
        if Mode.valid?(fsm_state) && fsm_state != Mode::ACTIVE
          return fsm_state
        end

        Mode::SHADOW
      end

      def configured_mode
        config = @snapshot.get
        configured = config.fetch("mode", @default_mode).to_s
        Mode.valid?(configured) ? configured : @default_mode
      end

      def serves_search?
        Mode.serves_search?(effective_mode)
      end

      def mirrors_writes?
        Mode.mirrors_writes?(effective_mode)
      end
    end
  end
end
