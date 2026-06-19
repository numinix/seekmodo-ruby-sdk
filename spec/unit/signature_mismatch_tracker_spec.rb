# frozen_string_literal: true

require "spec_helper"

RSpec.describe Seekmodo::Sdk::SignatureMismatchTracker do
  it "trips after threshold failures in window" do
    now = [1000]
    cache = Seekmodo::Sdk::Storage::Memory::Cache.new(-> { now[0] })
    tracker = Seekmodo::Sdk::SignatureMismatchTracker.new(cache, threshold: 3, clock: -> { now[0] })

    tracker.record_failure
    tracker.record_failure
    expect(tracker.tripped?).to be(false)
    tracker.record_failure
    expect(tracker.tripped?).to be(true)
  end
end
