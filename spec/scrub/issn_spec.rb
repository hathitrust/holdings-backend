# frozen_string_literal: true

require "scrub/issn"
require "services"

RSpec.describe Scrub::Issn do
  before(:each) do
    # Need to reset or the order of tests might affect tests passing.
    Services.register(:scrub_stats) { {} }
  end
  it "rejects invalid ISSNs" do
    expect(described_class.new("1").value).to eq([""])
    expect(described_class.new("12345-678").value).to eq([""])
    expect(described_class.new("123456789").value).to eq([""])
    expect(described_class.new("12345678X").value).to eq([""])
  end

  it "counts rejected ISSNs" do
    msg = "ISSN rejected (foo), does not match pattern."
    expect(Services.scrub_stats[msg].nil?).to be true
    described_class.new("foo")
    expect(Services.scrub_stats[msg]).to eq 1
  end

  it "accepts valid ISSNs" do
    expect(described_class.new("1234-5678").value).to eq(["1234-5678"])
    expect(described_class.new("12345678").value).to eq(["12345678"])
    expect(described_class.new("1234567X").value).to eq(["1234567X"])
  end

  it "filters out invalid ISSNs, leaving valid ones" do
    expect(described_class.new("1234567X, foo").value).to eq(["1234567X"])
  end
end
