# frozen_string_literal: true

require "spec_helper"
require "multi_part_overlap"

RSpec.describe MultiPartOverlap do
  let(:c) { build(:cluster) }
  let(:ht_w_ec) { build(:ht_item, ocns: c.ocns, bib_fmt: "mpm", enum_chron: "1", n_enum: "1") }
  let(:ht_wo_ec) { build(:ht_item, ocns: c.ocns, bib_fmt: "mpm", enum_chron: "", n_enum: "") }
  let(:h_w_ec) { build(:holding, ocn: c.ocns.first, enum_chron: "1", n_enum: "1") }
  let(:h_wo_ec) { build(:holding, ocn: c.ocns.first, enum_chron: "", n_enum: "") }
  let(:h_wrong_ec) { build(:holding, ocn: c.ocns.first, enum_chron: "2", n_enum: "2") }
  let(:h_lm) do
    build(:holding,
          ocn: c.ocns.first,
            organization: h_w_ec.organization,
            n_enum: "1",
            status: "LM")
  end

  let(:h_brt_wd) do
    build(:holding,
          ocn: c.ocns.first,
            organization: h_w_ec.organization,
            n_enum: "1",
            condition: "BRT",
            status: "WD")
  end

  before(:each) do
    Cluster.each(&:delete)
    c.save
    Clustering::ClusterHtItem.new(ht_w_ec).cluster.tap(&:save)
  end

  describe "#matching_holdings" do
    it "finds holdings that match on enum" do
      cluster = Clustering::ClusterHolding.new(h_w_ec).cluster.tap(&:save)
      overlap = described_class.new(cluster, h_w_ec.organization, ht_w_ec)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "finds holdings with no enum" do
      cluster = Clustering::ClusterHolding.new(h_wo_ec).cluster.tap(&:save)
      overlap = described_class.new(cluster, h_wo_ec.organization, ht_w_ec)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "does not find holdings with enum when ht item has no enum" do
      ht_w_ec.update_attributes(n_enum: "")
      cluster = Clustering::ClusterHolding.new(h_w_ec).cluster.tap(&:save)
      overlap = described_class.new(cluster, h_w_ec.organization, ht_w_ec)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(0)
    end

    it "chron is ignored for matching purposes" do
      ht_w_ec.update_attributes(n_chron: "Aug")
      ht_w_ec.update_attributes(n_enum_chron: "\tAug")
      cluster = Clustering::ClusterHolding.new(h_w_ec).cluster.tap(&:save)
      overlap = described_class.new(cluster, h_w_ec.organization, ht_w_ec)
      expect(h_w_ec.n_enum_chron).not_to eq(ht_w_ec.n_enum_chron)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "does not find holdings with the wrong enum" do
      cluster = Clustering::ClusterHolding.new(h_wrong_ec).cluster.tap(&:save)
      overlap = described_class.new(cluster, h_wrong_ec.organization, ht_w_ec)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(0)
    end

    it "does not find holdings if they have the wrong organization" do
      cluster = Clustering::ClusterHolding.new(h_w_ec).cluster.tap(&:save)
      overlap = described_class.new(cluster, "not_an_org", ht_w_ec)
      expect(overlap.matching_holdings.count).to eq(0)
    end
  end

  describe "#copy_count" do
    it "provides the correct copy count" do
      Clustering::ClusterHolding.new(h_w_ec).cluster.tap(&:save)
      cluster = Clustering::ClusterHolding.new(h_lm).cluster.tap(&:save)
      mpo = described_class.new(cluster, h_w_ec.organization, ht_w_ec)
      expect(mpo.copy_count).to eq(2)
    end

    it "returns 0 copies if wrong organization" do
      cluster = Clustering::ClusterHolding.new(h_w_ec).cluster.tap(&:save)
      mpo = described_class.new(cluster, "not_an_org", ht_w_ec)
      expect(mpo.copy_count).to be(0)
    end

    it "returns 1 copy if billing_entity matches" do
      ht_w_ec.update_attributes(billing_entity: "different_org")
      c.reload
      mpo = described_class.new(c, "different_org", ht_w_ec)
      expect(mpo.copy_count).to be(1)
    end

    it "returns 1 copy if org has a non-matching holding" do
      nmh = build(:holding, ocn: ht_w_ec.ocns.first, n_enum: "not matched")
      cluster = Clustering::ClusterHolding.new(nmh).cluster.tap(&:save)
      mpo = described_class.new(cluster, nmh.organization, ht_w_ec)
      expect(mpo.copy_count).to be(1)
    end
  end

  describe "#brt_count" do
    it "provides the correct brt count" do
      cluster = Clustering::ClusterHolding.new(h_brt_wd).cluster.tap(&:save)
      mpo = described_class.new(cluster, h_brt_wd.organization, ht_w_ec)
      expect(mpo.brt_count).to eq(1)
    end
  end

  describe "#wd_count" do
    it "provides the correct wd count" do
      cluster = Clustering::ClusterHolding.new(h_brt_wd).cluster.tap(&:save)
      mpo = described_class.new(cluster, h_brt_wd.organization, ht_w_ec)
      expect(mpo.wd_count).to eq(1)
    end
  end

  describe "#lm_count" do
    it "provides the correct lm count" do
      cluster = Clustering::ClusterHolding.new(h_lm).cluster.tap(&:save)
      mpo = described_class.new(cluster, h_lm.organization, ht_w_ec)
      expect(mpo.lm_count).to eq(1)
    end
  end

  describe "#access_count" do
    it "provides the correct access count" do
      Clustering::ClusterHolding.new(h_lm).cluster.tap(&:save)
      cluster = Clustering::ClusterHolding.new(h_brt_wd).cluster.tap(&:save)
      mpo = described_class.new(cluster, h_brt_wd.organization, ht_w_ec)
      expect(mpo.access_count).to eq(2)
    end
  end
end
