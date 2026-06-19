# frozen_string_literal: true

require_relative "transport"

module Seekmodo
  module Sdk
    module Storefront
      class Client
        attr_reader :transport, :recommend, :bundle

        def initialize(config)
          @transport = Transport.new(**config)
          @recommend = RecommendSurface.new(@transport)
          @bundle = BundleSurface.new(@transport)
        end

        def search(args = {}, opts = {})
          @transport.call("search", args, opts)
        end

        def suggest(args = {}, opts = {})
          @transport.call("suggest", args, opts)
        end

        def search_by_image(args = {}, opts = {})
          @transport.call("search.byImage", args, opts)
        end

        def chat(args = {}, opts = {})
          @transport.call("chat", args, opts)
        end

        def event(args = {}, opts = {})
          @transport.call("events", args, opts)
        end

        class RecommendSurface
          def initialize(transport)
            @transport = transport
          end

          def related(args = {}, opts = {})
            @transport.call("recommend.related", args, opts)
          end

          def also_bought(args = {}, opts = {})
            @transport.call("recommend.also_bought", args, opts)
          end

          def also_viewed(args = {}, opts = {})
            @transport.call("recommend.also_viewed", args, opts)
          end

          def trending(args = {}, opts = {})
            @transport.call("recommend.trending", args, opts)
          end
        end

        class BundleSurface
          def initialize(transport)
            @transport = transport
          end

          def suggest(args = {}, opts = {})
            @transport.call("bundle.suggest", args, opts)
          end
        end
      end
    end
  end
end
