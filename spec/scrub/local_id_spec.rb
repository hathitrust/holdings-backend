# frozen_string_literal: true

require "scrub/local_id"
require "services"

RSpec.describe Scrub::LocalId do
  it "rejects a nil local_id" do
    expect { described_class.new(nil) }.to raise_error ArgumentError
  end

  it "rejects a local_id that is too long" do
    expect(described_class.new("9" * 100).value).to eq([])
  end

  it "accepts any decent local_id" do
    expect(described_class.new("i1234567890").value).to eq(["i1234567890"])
    expect(described_class.new("1").value).to eq(["1"])
  end

  it "allows but trims spaces in local_id" do
    expect(described_class.new("  i1234567890  ").value).to eq(["i1234567890"])
  end
end
