# frozen_string_literal: true

require "spec_helper"

RSpec.describe Seekmodo::Sdk::Mode do
  it "validates known modes" do
    expect(Seekmodo::Sdk::Mode.valid?("shadow")).to be(true)
    expect(Seekmodo::Sdk::Mode.valid?("bogus")).to be(false)
  end

  it "serves search for shadow active enforce" do
    expect(Seekmodo::Sdk::Mode.serves_search?("shadow")).to be(true)
    expect(Seekmodo::Sdk::Mode.serves_search?("off")).to be(false)
  end
end
