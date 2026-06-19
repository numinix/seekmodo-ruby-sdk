# frozen_string_literal: true

require "spec_helper"

RSpec.describe Seekmodo::Sdk::BrowserToken do
  it "token is cached until near expiry" do
    gateway = MockGateway.new
    gateway.push_response(200, { "token" => "abc", "expires_at" => 2000, "issued_at" => 1000, "scope" => ["search"] })
    client = gateway.make_client
    cache = Seekmodo::Sdk::Storage::Memory::Cache.new(-> { 1000 })
    bt = Seekmodo::Sdk::BrowserToken.new(client, cache, clock: -> { 1000 })

    first = bt.token
    second = bt.token
    expect(first).to eq(second)
    expect(gateway.requests.length).to eq(1)
  end

  it "force bypasses cache" do
    gateway = MockGateway.new
    gateway.push_response(200, { "token" => "abc", "expires_at" => 2000, "issued_at" => 1000, "scope" => ["search"] })
    gateway.push_response(200, { "token" => "def", "expires_at" => 2000, "issued_at" => 1000, "scope" => ["search"] })
    client = gateway.make_client
    cache = Seekmodo::Sdk::Storage::Memory::Cache.new(-> { 1000 })
    bt = Seekmodo::Sdk::BrowserToken.new(client, cache, clock: -> { 1000 })

    bt.token
    refreshed = bt.token(force: true)
    expect(refreshed["token"]).to eq("def")
  end
end
