# frozen_string_literal: true

require "spec_helper"

RSpec.describe Seekmodo::Sdk::ModeFsm do
  it "open breaker forces off" do
    gateway = MockGateway.new
    client = gateway.make_client
    cache = Seekmodo::Sdk::Storage::Memory::Cache.new(-> { 1000 })
    cache.set(Seekmodo::Sdk::TenantSnapshot::CACHE_KEY, { "mode" => Seekmodo::Sdk::Mode::ENFORCE }, 300)
    cache.set(Seekmodo::Sdk::TenantSnapshot::CACHE_KEY_FETCHED_AT, 1000, 300)
    breaker = Seekmodo::Sdk::CircuitBreaker.new(
      Seekmodo::Sdk::Storage::Memory::BreakerStore.new,
      clock: -> { 1000 }
    )
    5.times { breaker.record_failure }

    snapshot = Seekmodo::Sdk::TenantSnapshot.new(client, cache, clock: -> { 1000 })
    fsm = Seekmodo::Sdk::ModeFsm.new(snapshot, breaker)
    expect(fsm.effective_mode).to eq(Seekmodo::Sdk::Mode::OFF)
  end

  it "active resolves fsm sub state" do
    gateway = MockGateway.new
    client = gateway.make_client
    cache = Seekmodo::Sdk::Storage::Memory::Cache.new(-> { 1000 })
    cache.set(
      Seekmodo::Sdk::TenantSnapshot::CACHE_KEY,
      { "mode" => Seekmodo::Sdk::Mode::ACTIVE, "fsm" => { "current_state" => Seekmodo::Sdk::Mode::ENFORCE } },
      300
    )
    cache.set(Seekmodo::Sdk::TenantSnapshot::CACHE_KEY_FETCHED_AT, 1000, 300)

    snapshot = Seekmodo::Sdk::TenantSnapshot.new(client, cache, clock: -> { 1000 })
    fsm = Seekmodo::Sdk::ModeFsm.new(snapshot)
    expect(fsm.effective_mode).to eq(Seekmodo::Sdk::Mode::ENFORCE)
  end
end
