# frozen_string_literal: true

require "spec_helper"

RSpec.describe "gateway wire contracts" do
  it "search endpoint contract" do
    request = load_fixture("search.request.json")
    response = load_fixture("search.response.json")
    gateway = MockGateway.new
    gateway.push_response(200, response)
    client = gateway.make_client

    result = client.search(request)
    req = gateway.last_request

    expect(req.method).to eq(:post)
    expect(req.url.path).to eq("/v1/search")
    expect(req.request_headers["content-type"]).to eq("application/json")
    expect(req.request_headers["x-seekmodo-tenant"]).to eq("redline")
    expect(JSON.parse(req.body)).to eq(request)

    expect(result["hits"]).to be_a(Array)
    expect(result["found"]).to be_a(Integer)
    expect(result["page"]).to be_a(Integer)
    expect(result["per_page"]).to be_a(Integer)
    expect(result).to include("took_ms", "bot_check")
    result["hits"].each { |hit| expect(hit).to include("id") }
  end

  it "index endpoint contract" do
    request = load_fixture("index.request.json")
    response = load_fixture("index.response.json")
    gateway = MockGateway.new
    gateway.push_response(200, response)
    client = gateway.make_client

    result = client.index(request["documents"], action: request["action"])
    req = gateway.last_request

    expect(req.method).to eq(:post)
    expect(req.url.path).to eq("/v1/index")
    sent = JSON.parse(req.body)
    expect(sent["documents"]).to eq(request["documents"])
    expect(sent["action"]).to eq(request["action"])
    expect(result["ok"]).to be(true)
    expect(result["imported"]).to be_a(Integer)
    expect(result["errors"]).to be_a(Array)
  end

  it "events endpoint contract" do
    request = load_fixture("events.request.json")
    response = load_fixture("events.response.json")
    gateway = MockGateway.new
    gateway.push_response(200, response)
    client = gateway.make_client

    client.events(request["events"])
    req = gateway.last_request

    expect(req.method).to eq(:post)
    expect(req.url.path).to eq("/v1/events")
    sent = JSON.parse(req.body)
    expect(sent["events"]).to eq(request["events"])
  end

  it "tenant handshake contract" do
    response = load_fixture("tenant_handshake.response.json")
    gateway = MockGateway.new
    gateway.push_response(200, response)
    client = gateway.make_client

    result = client.tenant_handshake
    req = gateway.last_request

    expect(req.method).to eq(:post)
    expect(req.url.path).to eq("/v1/tenant/handshake")
    expect(req.body).to eq("{}")
    expect(result["tenant_id"]).to eq("redline")
    expect(result["mode"]).to eq("shadow")
    expect(result["timeout_ms"]).to be_a(Integer)
    expect(result["index_batch"]).to be_a(Integer)
    expect(result["callback_host_allowlist"]).to be_a(Array)
    expect(result["fsm"]).to include("current_state")
    expect(result["plan"]).to include("tier")
  end

  it "tenants token contract" do
    response = load_fixture("tenants_token.response.json")
    gateway = MockGateway.new
    gateway.push_response(200, response)
    client = gateway.make_client

    result = client.browser_token
    req = gateway.last_request

    expect(req.method).to eq(:post)
    expect(req.url.path).to eq("/v1/tenants/token")
    expect(req.body).to eq("{}")
    expect(result["token"]).not_to be_nil
    expect(result["expires_at"]).to be_a(Integer)
    expect(result["issued_at"]).to be_a(Integer)
    expect(result["expires_at"]).to be > result["issued_at"]
    expect(result["scope"]).to be_a(Array)
  end

  it "tenants token with audience contract" do
    response = load_fixture("tenants_token.response.json")
    gateway = MockGateway.new
    gateway.push_response(200, response)
    client = gateway.make_client

    client.browser_token("storefront")
    sent = JSON.parse(gateway.last_request.body)
    expect(sent).to eq({ "audience" => "storefront" })
  end

  it "tenant paused error envelope contract" do
    error_body = load_fixture("error.tenant_paused.json")
    gateway = MockGateway.new
    gateway.push_response(403, error_body)
    client = gateway.make_client

    expect { client.search({ "q" => "a" }) }.to raise_error(Seekmodo::Sdk::TenantUnavailableError) do |exc|
      expect(exc.status_code).to eq(403)
      expect(exc.error_code).to eq("tenant_paused")
      expect(exc.is_transient?).to be(true)
      expect(exc.should_fallback?).to be(true)
    end
  end

  it "signature mismatch error envelope contract" do
    error_body = load_fixture("error.signature_mismatch.json")
    gateway = MockGateway.new
    gateway.push_response(401, error_body)
    client = gateway.make_client

    expect { client.search({ "q" => "a" }) }.to raise_error(Seekmodo::Sdk::SignatureMismatchError) do |exc|
      expect(exc.status_code).to eq(401)
      expect(exc.error_code).to eq("signature_mismatch")
    end
  end

  it "over quota error envelope contract" do
    error_body = load_fixture("error.over_quota.json")
    gateway = MockGateway.new
    gateway.push_response(402, error_body)
    client = gateway.make_client

    expect { client.search({ "q" => "a" }) }.to raise_error(Seekmodo::Sdk::OverQuotaError) do |exc|
      expect(exc.status_code).to eq(402)
      expect(exc.error_code).to eq("over_quota")
    end
  end

  it "click beacon payloads round trip through events endpoint" do
    gateway = MockGateway.new
    gateway.push_response(200, { "ok" => true, "accepted" => 1 })
    client = gateway.make_client

    client.events([Seekmodo::Sdk::Events::ClickBeacon.click("spark plug", "p-101", 1, false)])
    sent = JSON.parse(gateway.last_request.body)
    event = sent["events"][0]
    %w[type q doc_id position is_bot surface ts].each do |key|
      expect(event).to include(key)
    end
  end
end
