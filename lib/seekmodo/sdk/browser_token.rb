# frozen_string_literal: true

require_relative "connector/client"
require_relative "exceptions/client_error"
require_relative "storage/protocols"

module Seekmodo
  module Sdk
    class BrowserToken
      CACHE_KEY = "numinix.seekmodo.browser_token"
      SAFETY_MARGIN_SECONDS = 60

      def initialize(client, cache, clock: nil)
        @client = client
        @cache = cache
        @clock = clock || -> { Time.now.to_i }
      end

      def token(audience = nil, force: false)
        cache_key = "#{CACHE_KEY}:#{audience || 'default'}"
        unless force
          cached = @cache.get(cache_key)
          if cached.is_a?(Hash)
            expires_at = cached.fetch("expires_at", 0).to_i
            if expires_at > @clock.call + SAFETY_MARGIN_SECONDS
              return {
                "token" => cached["token"].to_s,
                "expires_at" => expires_at,
                "issued_at" => cached.fetch("issued_at", @clock.call).to_i
              }
            end
          end
        end

        response = @client.browser_token(audience)
        token = response["token"].to_s
        expires_at = response.fetch("expires_at", 0).to_i
        issued_at = response.fetch("issued_at", @clock.call).to_i

        if token.empty? || expires_at.zero?
          raise ClientError.new(
            "Gateway tenants.token response missing token/expires_at fields.",
            ClientError::KIND_BAD_RESPONSE
          )
        end

        value = {
          "token" => token,
          "expires_at" => expires_at,
          "issued_at" => issued_at
        }
        ttl = [expires_at - @clock.call - SAFETY_MARGIN_SECONDS, 1].max
        @cache.set(cache_key, value, ttl)
        value
      end

      def forget(audience = nil)
        @cache.delete("#{CACHE_KEY}:#{audience || 'default'}")
      end
    end
  end
end
