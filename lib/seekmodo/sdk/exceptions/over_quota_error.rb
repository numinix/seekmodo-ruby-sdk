# frozen_string_literal: true

require_relative "client_error"

module Seekmodo
  module Sdk
    class OverQuotaError < ClientError
    end
  end
end
