# frozen_string_literal: true

require "spec_helper"

RSpec.describe Seekmodo::Sdk::CircuitBreaker do
  def build_breaker(threshold: 5, window: 60, cooldown: 30, clock: nil)
    now = clock || [1000]
    tick = -> { now[0] }
    breaker = Seekmodo::Sdk::CircuitBreaker.new(
      Seekmodo::Sdk::Storage::Memory::BreakerStore.new,
      key: "test.breaker",
      failure_threshold: threshold,
      failure_window_seconds: window,
      open_cooldown_seconds: cooldown,
      clock: tick
    )
    [breaker, now]
  end

  it "starts closed and allows requests" do
    breaker, = build_breaker
    expect(breaker.state).to eq(Seekmodo::Sdk::CircuitBreaker::STATE_CLOSED)
    expect(breaker.allow_request?).to be(true)
  end

  it "trips open after threshold failures" do
    breaker, = build_breaker(threshold: 3)
    breaker.record_failure
    breaker.record_failure
    expect(breaker.state).to eq(Seekmodo::Sdk::CircuitBreaker::STATE_CLOSED)
    breaker.record_failure
    expect(breaker.state).to eq(Seekmodo::Sdk::CircuitBreaker::STATE_OPEN)
  end

  it "open breaker refuses requests" do
    breaker, now = build_breaker(threshold: 1, cooldown: 30)
    breaker.record_failure
    expect(breaker.state).to eq(Seekmodo::Sdk::CircuitBreaker::STATE_OPEN)
    expect(breaker.allow_request?).to be(false)
    now[0] = 1029
    expect(breaker.allow_request?).to be(false)
  end

  it "half open lets through one probe after cooldown" do
    breaker, now = build_breaker(threshold: 1, cooldown: 30)
    breaker.record_failure
    now[0] = 1031
    expect(breaker.allow_request?).to be(true)
    expect(breaker.state).to eq(Seekmodo::Sdk::CircuitBreaker::STATE_HALFOPEN)
    expect(breaker.allow_request?).to be(false)
  end

  it "half open success closes breaker" do
    breaker, now = build_breaker(threshold: 1, cooldown: 30)
    breaker.record_failure
    now[0] = 1031
    breaker.allow_request?
    breaker.record_success
    expect(breaker.state).to eq(Seekmodo::Sdk::CircuitBreaker::STATE_CLOSED)
  end

  it "half open failure reopens breaker" do
    breaker, now = build_breaker(threshold: 1, cooldown: 30)
    breaker.record_failure
    now[0] = 1031
    breaker.allow_request?
    breaker.record_failure
    expect(breaker.state).to eq(Seekmodo::Sdk::CircuitBreaker::STATE_OPEN)
  end

  it "failures outside window dont trip" do
    breaker, now = build_breaker(threshold: 3, window: 60)
    breaker.record_failure
    now[0] = 1090
    breaker.record_failure
    breaker.record_failure
    expect(breaker.state).to eq(Seekmodo::Sdk::CircuitBreaker::STATE_CLOSED)
  end
end
