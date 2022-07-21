# frozen_string_literal: true

require "scrub/gov_doc"
require "services"

RSpec.describe Scrub::GovDoc do
  it "allows and counts '0'" do
    expect(Services.scrub_stats["Scrub::GovDoc:0"].nil?).to be true
    expect(described_class.new("0").value).to eq ["0"]
    expect(Services.scrub_stats["Scrub::GovDoc:0"]).to eq 1
  end

  it "allows and counts '1'" do
    expect(Services.scrub_stats["Scrub::GovDoc:1"].nil?).to be true
    expect(described_class.new("1").value).to eq ["1"]
    expect(Services.scrub_stats["Scrub::GovDoc:1"]).to eq 1
  end

  it "allows and counts empties" do
    expect(Services.scrub_stats["Scrub::GovDoc:<empty>"].nil?).to be true
    expect(described_class.new("").value).to eq []
    expect(Services.scrub_stats["Scrub::GovDoc:<empty>"]).to eq 1
  end

  it "igores, but counts, anything else" do
    expect(Services.scrub_stats["Scrub::GovDoc:foo"].nil?).to be true
    expect(described_class.new("foo").value).to eq []
    expect(Services.scrub_stats["Scrub::GovDoc:foo"]).to eq 1
  end
end
