# frozen_string_literal: true

require "spec_helper"
require "overlap/multi_part_overlap"

RSpec.xdescribe Overlap::MultiPartOverlap do
  let(:c) { build(:cluster) }
  let(:htitem_with_enumchron) { build(:ht_item, :mpm, enum_chron: "1", n_enum: "1", ocns: c.ocns) }
  let(:htitem_no_enumchron) { build(:ht_item, :mpm, enum_chron: "", n_enum: "", ocns: c.ocns) }
  let(:holding_with_enumchron) { build(:holding, ocn: c.ocns.first, enum_chron: "1", n_enum: "1") }
  let(:holding_lost_missing) do
    build(:holding,
      ocn: c.ocns.first,
      organization: holding_with_enumchron.organization,
      n_enum: "1",
      status: "LM")
  end

  let(:holding_brittle_withdrawn) do
    build(:holding,
      ocn: c.ocns.first,
      organization: holding_with_enumchron.organization,
      n_enum: "1",
      condition: "BRT",
      status: "WD")
  end

  before(:each) do
    Cluster.each(&:delete)
    c.save
    Clustering::ClusterHtItem.new(htitem_with_enumchron).cluster.tap(&:save)
  end

  describe "#matching_holdings" do
    it "finds holdings that match on enum" do
      cluster = Clustering::ClusterHolding.new(holding_with_enumchron).cluster.tap(&:save)
      overlap = described_class.new(cluster, holding_with_enumchron.organization, htitem_with_enumchron)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "finds holdings with no enum" do
      holding_without_enumchron = build(:holding, ocn: c.ocns.first, enum_chron: "", n_enum: "")
      cluster = Clustering::ClusterHolding.new(holding_without_enumchron).cluster.tap(&:save)
      overlap = described_class.new(cluster, holding_without_enumchron.organization, htitem_with_enumchron)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "finds holdings with nil enum" do
      holding_nil_enumchron = build(:holding, ocn: c.ocns.first, enum_chron: "", n_enum: nil)
      cluster = Clustering::ClusterHolding.new(holding_nil_enumchron).cluster.tap(&:save)
      overlap = described_class.new(cluster, holding_nil_enumchron.organization, htitem_with_enumchron)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "does not find holdings with enum when ht item has no enum" do
      htitem_with_enumchron.update_attributes(n_enum: "")
      cluster = Clustering::ClusterHolding.new(holding_with_enumchron).cluster.tap(&:save)
      overlap = described_class.new(cluster, holding_with_enumchron.organization, htitem_with_enumchron)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(0)
    end

    it "chron is ignored for matching purposes" do
      htitem_with_enumchron.update_attributes(n_chron: "Aug")
      htitem_with_enumchron.update_attributes(n_enum_chron: "\tAug")
      cluster = Clustering::ClusterHolding.new(holding_with_enumchron).cluster.tap(&:save)
      overlap = described_class.new(cluster, holding_with_enumchron.organization, htitem_with_enumchron)
      expect(holding_with_enumchron.n_enum_chron).not_to eq(htitem_with_enumchron.n_enum_chron)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "does not find holdings with the wrong enum" do
      holding_wrong_enumchron = build(:holding, ocn: c.ocns.first, enum_chron: "2", n_enum: "2")
      cluster = Clustering::ClusterHolding.new(holding_wrong_enumchron).cluster.tap(&:save)
      overlap = described_class.new(cluster, holding_wrong_enumchron.organization, htitem_with_enumchron)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(0)
    end

    it "does not find holdings if they have the wrong organization" do
      cluster = Clustering::ClusterHolding.new(holding_with_enumchron).cluster.tap(&:save)
      overlap = described_class.new(cluster, "not_an_org", htitem_with_enumchron)
      expect(overlap.matching_holdings.count).to eq(0)
    end
  end

  describe "#copy_count" do
    it "provides the correct copy count" do
      Clustering::ClusterHolding.new(holding_with_enumchron).cluster.tap(&:save)
      cluster = Clustering::ClusterHolding.new(holding_lost_missing).cluster.tap(&:save)
      mpo = described_class.new(cluster, holding_with_enumchron.organization, htitem_with_enumchron)
      expect(mpo.copy_count).to eq(2)
    end

    it "returns 0 copies if wrong organization" do
      cluster = Clustering::ClusterHolding.new(holding_with_enumchron).cluster.tap(&:save)
      mpo = described_class.new(cluster, "not_an_org", htitem_with_enumchron)
      expect(mpo.copy_count).to be(0)
    end

    it "returns 1 copy if billing_entity matches" do
      htitem_with_enumchron.update_attributes(billing_entity: "different_org")
      c.reload
      mpo = described_class.new(c, "different_org", htitem_with_enumchron)
      expect(mpo.copy_count).to be(1)
    end

    it "returns 1 copy if org has a non-matching holding" do
      nmh = build(:holding, ocn: htitem_with_enumchron.ocns.first, n_enum: "not matched")
      cluster = Clustering::ClusterHolding.new(nmh).cluster.tap(&:save)
      mpo = described_class.new(cluster, nmh.organization, htitem_with_enumchron)
      expect(mpo.copy_count).to be(1)
    end
  end

  describe "#brt_count" do
    it "provides the correct brt count" do
      cluster = Clustering::ClusterHolding.new(holding_brittle_withdrawn).cluster.tap(&:save)
      mpo = described_class.new(cluster, holding_brittle_withdrawn.organization, htitem_with_enumchron)
      expect(mpo.brt_count).to eq(1)
    end
  end

  describe "#wd_count" do
    it "provides the correct wd count" do
      cluster = Clustering::ClusterHolding.new(holding_brittle_withdrawn).cluster.tap(&:save)
      mpo = described_class.new(cluster, holding_brittle_withdrawn.organization, htitem_with_enumchron)
      expect(mpo.wd_count).to eq(1)
    end
  end

  describe "#lm_count" do
    it "provides the correct lm count" do
      cluster = Clustering::ClusterHolding.new(holding_lost_missing).cluster.tap(&:save)
      mpo = described_class.new(cluster, holding_lost_missing.organization, htitem_with_enumchron)
      expect(mpo.lm_count).to eq(1)
    end
  end

  describe "#access_count" do
    it "provides the correct access count" do
      Clustering::ClusterHolding.new(holding_lost_missing).cluster.tap(&:save)
      cluster = Clustering::ClusterHolding.new(holding_brittle_withdrawn).cluster.tap(&:save)
      mpo = described_class.new(cluster, holding_brittle_withdrawn.organization, htitem_with_enumchron)
      expect(mpo.access_count).to eq(2)
    end
  end
end
