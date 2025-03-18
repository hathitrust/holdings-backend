# frozen_string_literal: true

require "spec_helper"
require "overlap/cluster_overlap"

RSpec.describe Overlap::ClusterOverlap do
  include_context "with tables for holdings"

  let(:spm) { build(:ht_item, enum_chron: "", billing_entity: "ucr") }
  let(:ocns) { spm.ocns }
  let(:cluster) { Cluster.for_ocns(ocns) }
  let(:holding) { build(:holding, ocn: ocns.first, organization: "umich") }
  let(:holding2) do
    build(:holding,
      ocn: ocns.first,
      organization: "smu",
      condition: "brt")
  end

  before(:each) do
    load_test_data(spm,holding,holding2)
  end

  describe "#each" do
    it "provides an overlap for each ht_item" do
      overlap = described_class.new(cluster, ["smu", "umich"])
      expect(overlap.each.count).to eq(2)
      overlap.each do |rec|
        expect(rec.to_hash[:volume_id]).to eq(spm.item_id)
        expect(rec.to_hash[:copy_count]).to eq(1)
      end
    end

    it "filters based on org" do
      overlap = described_class.new(cluster, "smu")
      expect(overlap.each.count).to eq(1)
    end

    it "returns everything if we don't give it an org" do
      overlap = described_class.new(cluster)
      expect(overlap.each.count).to eq(3)
    end
  end
end
