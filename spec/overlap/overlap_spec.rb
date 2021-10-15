# frozen_string_literal: true

require "spec_helper"
require "overlap"

RSpec.describe Overlap do
  context "with a cluster with an htitem and holdings" do
    let(:c) { build(:cluster) }
    let(:ht) { build(:ht_item, :spm, ocns: c.ocns) }
    let(:h) { build(:holding, ocn: c.ocns.first, organization: "umich", status: "lm") }
    let(:h2) do
      build(:holding,
            ocn: c.ocns.first,
              organization: "umich",
              condition: "brt",
              enum_chron: "V.1")
    end
    let(:h3) { build(:holding, ocn: c.ocns.first, organization: "smu") }

    before(:each) do
      Cluster.each(&:delete)
      c.save
      Clustering::ClusterHtItem.new(ht).cluster.tap(&:save)
      Clustering::ClusterHolding.new(h).cluster.tap(&:save)
      Clustering::ClusterHolding.new(h2).cluster.tap(&:save)
      Clustering::ClusterHolding.new(h3).cluster.tap(&:save)
      c.reload
    end

    describe "#to_hash" do
      it "returns a mostly empty hash" do
        overlap_hash = described_class.new(c, h.organization, ht).to_hash
        expect(overlap_hash).to eq(lock_id: c._id.to_s, cluster_id: c._id.to_s,
            volume_id: ht.item_id,
            member_id: h.organization,
            n_enum: "",
            # Counts are overridden by subclasses
            copy_count: 0,
            brt_count: 0,
            wd_count: 0,
            lm_count: 0,
            access_count: 0)
      end
    end

    describe "#matching_holdings" do
      it "finds all matching holdings for an org" do
        overlap = described_class.new(c, "umich", ht)
        expect(overlap.matching_holdings.pluck(:organization)).to eq(["umich", "umich"])
      end
    end
  end

  describe "#lock_id" do
    it "computes a lock id for an SPM" do
      ht_item = build(:ht_item, :spm)
      cluster = Clustering::ClusterHtItem.new(ht_item).cluster
      overlap = described_class.new(cluster, "an_org", ht_item)
      expect(cluster.format).to eq("spm")
      expect(overlap.lock_id).to eq(cluster._id.to_s)
    end

    it "computes a lock id for an MPM" do
      ht_item = build(:ht_item, :mpm,  n_enum: "V.1")
      cluster = Clustering::ClusterHtItem.new(ht_item).cluster
      overlap = described_class.new(cluster, "an_org", ht_item)
      expect(cluster.format).to eq("mpm")
      expect(overlap.lock_id).to eq("#{cluster._id}:V.1")
    end

    it "computes a lock id for an SER" do
      ht_item = build(:ht_item, :ser, n_enum: "V.1")
      cluster = Clustering::ClusterHtItem.new(ht_item).cluster
      overlap = described_class.new(cluster, "an_org", ht_item)
      expect(cluster.format).to eq("ser")
      expect(overlap.lock_id).to eq(ht_item.item_id)
    end
  end
end
