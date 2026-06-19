# frozen_string_literal: true

require_relative "seekmodo_error"

module Seekmodo
  module Sdk
    class ClientError < SeekmodoError
      KIND_NOT_CONFIGURED = "not_configured"
      KIND_BREAKER_OPEN = "breaker_open"
      KIND_NETWORK = "network"
      KIND_TIMEOUT = "timeout"
      KIND_HTTP_4XX = "http_4xx"
      KIND_HTTP_5XX = "http_5xx"
      KIND_BAD_RESPONSE = "bad_response"
      KIND_SIGNATURE_MISMATCH = "signature_mismatch"
      KIND_RATE_LIMITED = "rate_limited"
      KIND_OVER_QUOTA = "over_quota"
      KIND_TENANT_UNAVAILABLE = "tenant_unavailable"

      TENANT_UNAVAILABLE_ERROR_CODES = %w[
        tenant_paused tenant_not_found tenant_unknown tenant_suspended tenant_disabled
      ].freeze

      attr_reader :kind, :status_code, :body

      def initialize(message, kind, status_code = 0, body: nil, cause: nil)
        super(message)
        @kind = kind
        @status_code = status_code
        @body = body || {}
        set_backtrace(cause&.backtrace) if cause
      end

      def is_transient?
        [
          KIND_NETWORK,
          KIND_TIMEOUT,
          KIND_HTTP_5XX,
          KIND_TENANT_UNAVAILABLE
        ].include?(kind)
      end

      def should_fallback?
        kind != KIND_HTTP_4XX
      end

      def error_code
        err = body["error"]
        err.is_a?(String) ? err : nil
      end

      def self.classify_error_code(error_code)
        return nil if error_code.nil? || error_code.empty?

        if TENANT_UNAVAILABLE_ERROR_CODES.include?(error_code)
          return KIND_TENANT_UNAVAILABLE
        end
        return KIND_SIGNATURE_MISMATCH if error_code == "signature_mismatch"
        return KIND_RATE_LIMITED if error_code == "rate_limited"
        return KIND_OVER_QUOTA if %w[over_quota feature_not_in_plan].include?(error_code)

        nil
      end
    end
  end
end
