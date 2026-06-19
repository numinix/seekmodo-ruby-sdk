# frozen_string_literal: true

require "openssl"

module Seekmodo
  module Sdk
    class HmacSigner
      HEADER_TENANT = "X-Seekmodo-Tenant"
      HEADER_SIGNATURE = "X-Seekmodo-Signature"
      HEADER_TIMESTAMP = "X-Seekmodo-Timestamp"
      HEADER_SESSION = "X-Seekmodo-Session"
      HEADER_STOREFRONT_HOST = "X-Seekmodo-Storefront-Host"

      attr_reader :tenant_id

      def initialize(tenant_id, shared_secret)
        @tenant_id = tenant_id
        @shared_secret = shared_secret
      end

      def headers(raw_body, timestamp = nil)
        ts = (timestamp || Time.now.to_i).to_s
        signature = OpenSSL::HMAC.hexdigest("SHA256", @shared_secret, raw_body)
        {
          HEADER_TENANT => @tenant_id,
          HEADER_SIGNATURE => signature,
          HEADER_TIMESTAMP => ts
        }
      end

      def verify(raw_body, signature)
        expected = OpenSSL::HMAC.hexdigest("SHA256", @shared_secret, raw_body)
        return false if signature.nil? || signature.empty?

        OpenSSL.secure_compare(expected, signature)
      end

      def configured?
        !@tenant_id.to_s.empty? && !@shared_secret.to_s.empty?
      end
    end
  end
end
