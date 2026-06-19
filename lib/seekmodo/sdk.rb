# frozen_string_literal: true

require_relative "seekmodo/sdk/version"
require_relative "seekmodo/sdk/exceptions/seekmodo_error"
require_relative "seekmodo/sdk/exceptions/client_error"
require_relative "seekmodo/sdk/exceptions/tenant_unavailable_error"
require_relative "seekmodo/sdk/exceptions/over_quota_error"
require_relative "seekmodo/sdk/exceptions/signature_mismatch_error"
require_relative "seekmodo/sdk/exceptions/breaker_open_error"
require_relative "seekmodo/sdk/hmac_signer"
require_relative "seekmodo/sdk/mode"
require_relative "seekmodo/sdk/circuit_breaker"
require_relative "seekmodo/sdk/connector/client"
require_relative "seekmodo/sdk/tenant_snapshot"
require_relative "seekmodo/sdk/mode_fsm"
require_relative "seekmodo/sdk/auto_promoter"
require_relative "seekmodo/sdk/pairing"
require_relative "seekmodo/sdk/browser_token"
require_relative "seekmodo/sdk/signature_mismatch_tracker"
require_relative "seekmodo/sdk/storage/protocols"
require_relative "seekmodo/sdk/storage/memory/stores"
require_relative "seekmodo/sdk/events/click_beacon"
require_relative "seekmodo/sdk/events/events_queue"
require_relative "seekmodo/sdk/storefront/transport"
require_relative "seekmodo/sdk/storefront/client"
require_relative "seekmodo/sdk/admin/client"
require_relative "seekmodo/sdk/mcp/client"
require_relative "seekmodo/sdk/tools/registry"

module Seekmodo
  module Sdk
  end
end
