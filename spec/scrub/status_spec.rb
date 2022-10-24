# frozen_string_literal: true

require "scrub/status"
require "services"

RSpec.describe Scrub::Status do
  before(:each) do
    # Need to reset or the order of tests might affect tests passing.
    Services.register(:scrub_stats) { {} }
  end
  it "keeps tally of what was rejected & why" do
    Services.register(:scrub_stats) { {} }
    stats_key = "Scrub::Status:foo"
    expect(Services.scrub_stats[stats_key]).to eq nil
    described_class.new("foo")
    expect(Services.scrub_stats[stats_key]).to eq(1)
    described_class.new("foo")
    expect(Services.scrub_stats[stats_key]).to eq(2)
  end

  it "accepts allowed status" do
    expect(described_class.new("CH").value).to eq(["CH"])
    expect(described_class.new("LM").value).to eq(["LM"])
    expect(described_class.new("WD").value).to eq(["WD"])
  end

  it "rejects bad status" do
    expect(described_class.new("BRT").value).to eq([])
    expect(described_class.new("X").value).to eq([])
    expect(described_class.new("").value).to eq([])
  end
end
