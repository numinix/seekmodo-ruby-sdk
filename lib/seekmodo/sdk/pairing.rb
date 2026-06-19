# frozen_string_literal: true

require "base64"
require "json"
require "jwt"
require "openssl"
require "faraday"

require_relative "exceptions/seekmodo_error"
require_relative "storage/protocols"

module Seekmodo
  module Sdk
    class Pairing
      DEFAULT_JWKS_URL = "https://seekmodo.com/.well-known/jwks.json"
      KEYS_CACHE_KEY = "numinix.seekmodo.pairing.jwks"
      KEYS_CACHE_TTL_SECONDS = 86400
      MAX_TOKEN_AGE_SECONDS = 600

      def initialize(connection, cache, jwks_url: DEFAULT_JWKS_URL, clock: nil)
        @connection = connection
        @cache = cache
        @jwks_url = jwks_url
        @clock = clock || -> { Time.now.to_i }
      end

      def verify_and_extract(jwt_token)
        header, payload, _sig = JWT.decode(jwt_token, nil, false)
        alg = header["alg"].to_s
        raise SeekmodoError, "Unsupported pairing JWT alg \"#{alg}\"; expected EdDSA." unless alg == "EdDSA"

        kid = header["kid"].to_s
        raise SeekmodoError, "Pairing JWT is missing kid header." if kid.empty?

        jwk = lookup_key(kid, refresh: false)
        jwk = lookup_key(kid, refresh: true) if jwk.nil?
        raise SeekmodoError, "No pairing JWKS key matches kid=\"#{kid}\"; rotation lag?" if jwk.nil?

        public_key_raw = base64url_decode(jwk["x"].to_s)
        raise SeekmodoError, "Pairing JWKS key has wrong byte length for Ed25519." unless public_key_raw.bytesize == 32

        public_key = OpenSSL::PKey.read({
          kty: "OKP",
          crv: "Ed25519",
          x: jwk["x"]
        }.to_json)

        JWT.decode(
          jwt_token,
          public_key,
          true,
          { algorithm: "EdDSA" }
        )

        now = @clock.call
        exp = payload["exp"].to_i
        iat = payload["iat"].to_i
        raise SeekmodoError, "Pairing JWT has expired." if exp > 0 && exp < now
        raise SeekmodoError, "Pairing JWT is older than the 10-minute replay window." if iat > 0 && now - iat > MAX_TOKEN_AGE_SECONDS

        payload
      rescue JWT::DecodeError => e
        raise SeekmodoError, "Pairing JWT signature verification failed.", e.backtrace
      end

      def refresh_keys
        fetch_keys
      end

      private

      def lookup_key(kid, refresh:)
        keys_doc = refresh ? fetch_keys : cached_keys
        keys_doc.fetch("keys", []).find { |key| key.is_a?(Hash) && key["kid"] == kid }
      end

      def cached_keys
        cached = @cache.get(KEYS_CACHE_KEY)
        return cached if cached.is_a?(Hash)

        fetch_keys
      end

      def fetch_keys
        response = @connection.get(@jwks_url) do |req|
          req.headers["Accept"] = "application/json"
        end

        raise SeekmodoError, "JWKS fetch returned HTTP #{response.status}" unless response.status == 200

        body = JSON.parse(response.body)
        unless body.is_a?(Hash) && body["keys"].is_a?(Array) && body["keys"].any?
          raise SeekmodoError, 'JWKS response did not contain a "keys" array.'
        end

        @cache.set(KEYS_CACHE_KEY, body, KEYS_CACHE_TTL_SECONDS)
        body
      rescue Faraday::Error => e
        raise SeekmodoError, "Failed to fetch Seekmodo pairing JWKS: #{e.message}"
      rescue JSON::ParserError => e
        raise SeekmodoError, "JWKS response was not valid JSON: #{e.message}"
      end

      def base64url_decode(segment)
        padded = segment.tr("-_", "+/")
        remainder = padded.length % 4
        padded += "=" * (4 - remainder) if remainder.positive?
        Base64.decode64(padded)
      rescue ArgumentError => e
        raise SeekmodoError, "Pairing JWT contains malformed base64url segment.", e.backtrace
      end
    end
  end
end
