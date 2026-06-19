# frozen_string_literal: true

require_relative "client_error"

module Seekmodo
  module Sdk
    class TenantUnavailableError < ClientError
    end
  end
end
