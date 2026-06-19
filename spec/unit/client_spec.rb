# frozen_string_literal: true

require "spec_helper"

RSpec.describe Seekmodo::Sdk::Connector::Client do
  it "health is unsigned" do
    gateway = MockGateway.new
    gateway.push_response(200, { "ok" => true })
    client = gateway.make_client
    result = client.health
    expect(result["ok"]).to be(true)
    expect(gateway.last_request.request_headers).not_to include("x-seekmodo-tenant")
  end

  it "tools get request" do
    gateway = MockGateway.new
    gateway.push_response(200, { "tools" => [] })
    client = gateway.make_client
    client.tools
    expect(gateway.last_request.method).to eq(:get)
    expect(gateway.last_request.url.path).to eq("/v1/tools")
  end

  it "index auto chunks large batches" do
    gateway = MockGateway.new
    gateway.push_response(200, { "ok" => true, "imported" => 500, "errors" => [] })
    gateway.push_response(200, { "ok" => true, "imported" => 500, "errors" => [] })
    gateway.push_response(200, { "ok" => true, "imported" => 200, "errors" => [] })
    client = gateway.make_client
    docs = (0...1200).map { |i| { "id" => "doc-#{i}" } }
    result = client.index(docs)
    expect(result["imported"]).to eq(1200)
    expect(gateway.requests.length).to eq(3)
  end

  it "raises when signer not configured" do
    gateway = MockGateway.new
    client = Seekmodo::Sdk::Connector::Client.new(
      Seekmodo::Sdk::HmacSigner.new("", ""),
      connection: gateway.make_client.instance_variable_get(:@connection)
    )
    expect { client.search({ "q" => "a" }) }.to raise_error(Seekmodo::Sdk::ClientError) do |e|
      expect(e.kind).to eq(Seekmodo::Sdk::ClientError::KIND_NOT_CONFIGURED)
    end
  end

  it "raises when breaker open" do
    gateway = MockGateway.new
    breaker = Seekmodo::Sdk::CircuitBreaker.new(
      Seekmodo::Sdk::Storage::Memory::BreakerStore.new,
      failure_threshold: 1
    )
    breaker.record_failure
    client = Seekmodo::Sdk::Connector::Client.new(
      Seekmodo::Sdk::HmacSigner.new(TENANT_ID, SECRET),
      breaker: breaker,
      connection: gateway.make_client.instance_variable_get(:@connection)
    )
    expect { client.search({ "q" => "a" }) }.to raise_error(Seekmodo::Sdk::ClientError) do |e|
      expect(e.kind).to eq(Seekmodo::Sdk::ClientError::KIND_BREAKER_OPEN)
    end
  end

  it "tenant_snapshot uses tenant.snapshot path" do
    gateway = MockGateway.new
    gateway.push_response(200, { "mode" => "shadow" })
    client = gateway.make_client
    client.tenant_snapshot
    expect(gateway.last_request.url.path).to eq("/v1/tenant.snapshot")
  end
end
