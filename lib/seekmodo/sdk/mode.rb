# frozen_string_literal: true

module Seekmodo
  module Sdk
    module Mode
      OFF = "off"
      LEARNING = "learning"
      SHADOW = "shadow"
      ACTIVE = "active"
      ENFORCE = "enforce"

      ALL = [OFF, LEARNING, SHADOW, ACTIVE, ENFORCE].freeze

      module_function

      def values
        ALL
      end

      def valid?(mode)
        ALL.include?(mode)
      end

      def assert_mode(mode)
        unless valid?(mode)
          raise ArgumentError, "Unknown Seekmodo mode '#{mode}'; expected one of: #{ALL.join(', ')}"
        end

        mode
      end

      def serves_search?(mode)
        [SHADOW, ACTIVE, ENFORCE].include?(mode)
      end

      def mirrors_writes?(mode)
        mode != OFF
      end
    end
  end
end
