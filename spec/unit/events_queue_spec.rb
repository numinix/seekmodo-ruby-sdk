# frozen_string_literal: true

require "spec_helper"

RSpec.describe Seekmodo::Sdk::Events::EventsQueue do
  it "flushes batch to connector" do
    gateway = MockGateway.new
    gateway.push_response(200, { "ok" => true, "accepted" => 2 })
    client = gateway.make_client
    store = Seekmodo::Sdk::Storage::Memory::EventQueueStore.new
    queue = Seekmodo::Sdk::Events::EventsQueue.new(client, store)

    queue.push({ "type" => "click" })
    queue.push({ "type" => "search" })
    count = queue.flush
    expect(count).to eq(2)
    expect(store.count).to eq(0)
  end

  it "requeues on failure" do
    gateway = MockGateway.new
    gateway.push_response(503, { "error" => "down" })
    client = gateway.make_client
    store = Seekmodo::Sdk::Storage::Memory::EventQueueStore.new
    queue = Seekmodo::Sdk::Events::EventsQueue.new(client, store)

    queue.push({ "type" => "click" })
    count = queue.flush
    expect(count).to eq(0)
    expect(store.count).to eq(1)
  end
end
