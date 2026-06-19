# frozen_string_literal: true

require "spec_helper"
require "openssl"

RSpec.describe Seekmodo::Sdk::HmacSigner do
  it "headers are byte equivalent to gateway contract" do
    signer = Seekmodo::Sdk::HmacSigner.new("redline", "super-secret-key")
    body = '{"q":"hex socket cap","per_page":12}'
    headers = signer.headers(body, 1_717_286_400)
    expected_sig = OpenSSL::HMAC.hexdigest("SHA256", "super-secret-key", body)
    expect(headers["X-Seekmodo-Tenant"]).to eq("redline")
    expect(headers["X-Seekmodo-Signature"]).to eq(expected_sig)
    expect(headers["X-Seekmodo-Timestamp"]).to eq("1717286400")
  end

  it "headers default timestamp to now" do
    signer = Seekmodo::Sdk::HmacSigner.new("redline", "super-secret-key")
    before = Time.now.to_i
    headers = signer.headers("{}")
    after = Time.now.to_i
    ts = headers["X-Seekmodo-Timestamp"].to_i
    expect(ts).to be_between(before, after)
  end

  it "verify accepts matching signature" do
    signer = Seekmodo::Sdk::HmacSigner.new("redline", "super-secret-key")
    body = '{"hello":"world"}'
    expected = OpenSSL::HMAC.hexdigest("SHA256", "super-secret-key", body)
    expect(signer.verify(body, expected)).to be(true)
  end

  it "verify rejects bad signature" do
    signer = Seekmodo::Sdk::HmacSigner.new("redline", "super-secret-key")
    expect(signer.verify('{"hello":"world"}', "wrong")).to be(false)
  end

  it "configured false for blank values" do
    expect(Seekmodo::Sdk::HmacSigner.new("", "").configured?).to be(false)
    expect(Seekmodo::Sdk::HmacSigner.new("redline", "").configured?).to be(false)
    expect(Seekmodo::Sdk::HmacSigner.new("", "secret").configured?).to be(false)
    expect(Seekmodo::Sdk::HmacSigner.new("redline", "secret").configured?).to be(true)
  end
end
