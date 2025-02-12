# frozen_string_literal: true

require "spec_helper"
require "loader/ocn_resolution_loader"

RSpec.describe Loader::OCNResolutionLoader do
  let(:line) do
    [
      "123", # variant
      "456" # canonical
    ].join("\t")
  end

  describe "#item_from_line" do
    let(:resolution) { described_class.new.item_from_line(line) }

    it { expect(resolution).to be_a(Clusterable::OCNResolution) }
    it { expect(resolution.variant).to eq 123 }
    it { expect(resolution.canonical).to eq 456 }
  end

  describe "#load" do
    include_context "with tables for holdings"

    it "persists a batch of OCNResolutions" do
      resolution1 = build(:ocn_resolution)
      resolution2 = build(:ocn_resolution, canonical: resolution1.canonical)

      described_class.new.load([resolution1, resolution2])

      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ocn_resolutions.count).to eq(2)
      expect(Cluster.first.ocns)
        .to contain_exactly(resolution1.canonical, resolution1.variant, resolution2.variant)
    end
  end
end
