# frozen_string_literal: true

require_relative "sdk/version"
require_relative "sdk/exceptions/seekmodo_error"
require_relative "sdk/exceptions/client_error"
require_relative "sdk/exceptions/tenant_unavailable_error"
require_relative "sdk/exceptions/over_quota_error"
require_relative "sdk/exceptions/signature_mismatch_error"
require_relative "sdk/exceptions/breaker_open_error"
require_relative "sdk/hmac_signer"
require_relative "sdk/mode"
require_relative "sdk/circuit_breaker"
require_relative "sdk/connector/client"
require_relative "sdk/tenant_snapshot"
require_relative "sdk/mode_fsm"
require_relative "sdk/auto_promoter"
require_relative "sdk/pairing"
require_relative "sdk/browser_token"
require_relative "sdk/signature_mismatch_tracker"
require_relative "sdk/storage/protocols"
require_relative "sdk/storage/memory/stores"
require_relative "sdk/events/click_beacon"
require_relative "sdk/events/events_queue"
require_relative "sdk/storefront/transport"
require_relative "sdk/storefront/client"
require_relative "sdk/admin/client"
require_relative "sdk/mcp/client"
require_relative "sdk/tools/registry"

module Seekmodo
  module Sdk
  end
end
