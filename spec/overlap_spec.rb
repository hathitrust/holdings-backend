# frozen_string_literal: true

require "spec_helper"
require "overlap"

RSpec.describe Overlap do
  let(:c) { build(:cluster) }
  let(:ht) { build(:ht_item, ocns: c.ocns, bib_fmt: "ser", enum_chron: "") }
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
    ClusterHtItem.new(ht).cluster.tap(&:save)
    ClusterHolding.new(h).cluster.tap(&:save)
    ClusterHolding.new(h2).cluster.tap(&:save)
    ClusterHolding.new(h3).cluster.tap(&:save)
    c.reload
  end

  describe "#to_hash" do
    it "returns a mostly empty hash" do
      overlap_hash = described_class.new(c, h.organization, ht).to_hash
      expect(overlap_hash).to eq(lock_id: c._id.to_s, cluster_id: c._id.to_s,
          volume_id: ht.item_id,
          member_id: h.organization,
          n_enum: "",
          copy_count: "",
          brt_count: "",
          wd_count: "",
          lm_count: "",
          access_count: "")
    end
  end

  describe "#matching_holdings" do
    it "finds all matching holdings for an org" do
      overlap = described_class.new(c, "umich", ht)
      expect(overlap.matching_holdings.pluck(:organization)).to eq(["umich", "umich"])
    end
  end

  describe "#lock_id" do
    let(:cluster) { build(:cluster, _id: "a_cluster_id") }
    let(:ht_item) { build(:ht_item, ocns: cluster.ocns) }

    it "computes a lock id for an SPM" do
      overlap = described_class.new(cluster, "an_org", ht_item)
      expect(cluster.format).to eq("spm")
      expect(overlap.lock_id).to eq("a_cluster_id")
    end

    it "computes a lock id for an MPM" do
      ht_item.n_enum = "V.1"
      cluster = ClusterHtItem.new(ht_item).cluster
      overlap = described_class.new(cluster, "an_org", ht_item)
      expect(cluster.format).to eq("mpm")
      expect(overlap.lock_id).to eq("#{cluster._id}:V.1")
    end

    it "computes a lock id for an SER" do
      ht_item.n_enum = "V.1"
      Services.serials.bibkeys.add(ht_item.ht_bib_key.to_i)
      cluster = ClusterHtItem.new(ht_item).cluster
      overlap = described_class.new(cluster, "an_org", ht_item)
      expect(cluster.format).to eq("ser")
      expect(overlap.lock_id).to eq(ht_item.item_id)
    end
  end
end
