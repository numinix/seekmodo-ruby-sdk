# frozen_string_literal: true

require "spec_helper"

RSpec.describe Seekmodo::Sdk::ClientError do
  it "classifies tenant unavailable codes" do
    Seekmodo::Sdk::ClientError::TENANT_UNAVAILABLE_ERROR_CODES.each do |code|
      expect(Seekmodo::Sdk::ClientError.classify_error_code(code)).to eq(
        Seekmodo::Sdk::ClientError::KIND_TENANT_UNAVAILABLE
      )
    end
  end

  it "should fallback for transient kinds" do
    exc = Seekmodo::Sdk::ClientError.new("x", Seekmodo::Sdk::ClientError::KIND_HTTP_5XX, 503)
    expect(exc.should_fallback?).to be(true)
    expect(exc.is_transient?).to be(true)
  end

  it "should not fallback for plain 4xx" do
    exc = Seekmodo::Sdk::ClientError.new("x", Seekmodo::Sdk::ClientError::KIND_HTTP_4XX, 400)
    expect(exc.should_fallback?).to be(false)
    expect(exc.is_transient?).to be(false)
  end

  it "tenant unavailable should fallback despite 4xx status" do
    exc = Seekmodo::Sdk::ClientError.new(
      "paused",
      Seekmodo::Sdk::ClientError::KIND_TENANT_UNAVAILABLE,
      403,
      body: { "error" => "tenant_paused" }
    )
    expect(exc.should_fallback?).to be(true)
    expect(exc.is_transient?).to be(true)
  end
end
