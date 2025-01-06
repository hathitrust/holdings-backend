# frozen_string_literal: true

require "spec_helper"
require "loader/ocn_resolution_loader"

RSpec.xdescribe Loader::OCNResolutionLoader do
  let(:line) do
    [
      "123", # deprecated
      "456" # resolved
    ].join("\t")
  end

  describe "#item_from_line" do
    let(:resolution) { described_class.new.item_from_line(line) }

    it { expect(resolution).to be_a(Clusterable::OCNResolution) }
    it { expect(resolution.deprecated).to eq 123 }
    it { expect(resolution.resolved).to eq 456 }
  end

  describe "#load" do
    before(:each) { Cluster.each(&:delete) }

    it "persists a batch of OCNResolutions" do
      resolution1 = build(:ocn_resolution)
      resolution2 = build(:ocn_resolution, resolved: resolution1.resolved)

      described_class.new.load([resolution1, resolution2])

      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ocn_resolutions.count).to eq(2)
      expect(Cluster.first.ocns)
        .to contain_exactly(resolution1.resolved, resolution1.deprecated, resolution2.deprecated)
    end
  end
end
