# frozen_string_literal: true

require "scrub/condition"
require "services"

RSpec.describe Scrub::Condition do
  before(:each) do
    # Need to reset or the order of tests might affect tests passing.
    Services.register(:scrub_stats) { {} }
  end
  it "allows and counts 'BRT'" do
    expect(Services.scrub_stats["Scrub::Condition:BRT"].nil?).to be true
    expect(described_class.new("BRT").value).to eq ["BRT"]
    expect(Services.scrub_stats["Scrub::Condition:BRT"]).to eq 1
    described_class.new("BRT")
    expect(Services.scrub_stats["Scrub::Condition:BRT"]).to eq 2
  end

  it "allows and counts empties" do
    expect(Services.scrub_stats["Scrub::Condition:<empty>"].nil?).to be true
    expect(described_class.new("").value).to eq []
    expect(Services.scrub_stats["Scrub::Condition:<empty>"]).to eq 1
  end

  it "ignores (but counts) everything else" do
    expect(Services.scrub_stats["Scrub::Condition:a"].nil?).to be true
    expect(described_class.new("a").value).to eq []
    expect(Services.scrub_stats["Scrub::Condition:a"]).to eq 1
  end
end
