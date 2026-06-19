# frozen_string_literal: true

require "spec_helper"

RSpec.describe Seekmodo::Sdk::Events::ClickBeacon do
  it "click includes required fields" do
    event = Seekmodo::Sdk::Events::ClickBeacon.click("query", "doc-1", 2, false)
    expect(event["type"]).to eq("click")
    expect(event["doc_id"]).to eq("doc-1")
  end

  it "impression includes doc ids" do
    event = Seekmodo::Sdk::Events::ClickBeacon.impression("query", %w[a b], false, shopper_context: { "session" => "x" })
    expect(event["doc_ids"]).to eq(%w[a b])
    expect(event["shopper"]).to eq({ "session" => "x" })
  end

  it "search event shape" do
    event = Seekmodo::Sdk::Events::ClickBeacon.search("query", 12, true, extra: { "source" => "test" })
    expect(event["hits"]).to eq(12)
    expect(event["source"]).to eq("test")
  end
end
