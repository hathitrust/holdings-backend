# frozen_string_literal: true

require "spec_helper"
require "overlap/multi_part_overlap"

RSpec.describe Overlap::MultiPartOverlap do
  include_context "with tables for holdings"

  let(:htitem_with_enumchron) do
    build(:ht_item,
      :mpm,
      enum_chron: "1",
      n_enum: "1",
      collection_code: "PU")
  end

  let(:ocns) { htitem_with_enumchron.ocns }

  let(:htitem_no_enumchron) do
    build(:ht_item,
      :mpm,
      enum_chron: "",
      n_enum: "",
      ocns: ocns,
      collection_code: "PU")
  end

  let(:c) { Cluster.new(ocns: htitem_with_enumchron.ocns) }

  let(:holding_with_enumchron) do
    build(:holding,
      ocn: ocns.first,
      organization: "umich",
      enum_chron: "1",
      n_enum: "1")
  end

  let(:holding_lost_missing) do
    build(:holding,
      ocn: ocns.first,
      organization: holding_with_enumchron.organization,
      n_enum: "1",
      status: "LM")
  end

  let(:holding_brittle_withdrawn) do
    build(:holding,
      ocn: ocns.first,
      organization: holding_with_enumchron.organization,
      n_enum: "1",
      condition: "BRT",
      status: "WD")
  end

  before(:each) do
    insert_htitem(htitem_with_enumchron)
  end

  describe "#matching_holdings" do
    it "finds holdings that match on enum" do
      holding_with_enumchron.save
      cluster = holding_with_enumchron.cluster
      overlap = described_class.new(cluster, holding_with_enumchron.organization, htitem_with_enumchron)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "finds holdings with no enum" do
      holding_without_enumchron = create(:holding, ocn: c.ocns.first, enum_chron: "", n_enum: "")
      cluster = holding_without_enumchron.cluster
      overlap = described_class.new(cluster, holding_without_enumchron.organization, htitem_with_enumchron)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "finds holdings with nil enum" do
      holding_nil_enumchron = create(:holding, ocn: c.ocns.first, enum_chron: "", n_enum: nil)
      cluster = holding_nil_enumchron.cluster
      overlap = described_class.new(cluster, holding_nil_enumchron.organization, htitem_with_enumchron)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "does not find holdings with enum when ht item has no enum" do
      htitem_with_enumchron.n_enum = ""
      holding_with_enumchron.save
      cluster = holding_with_enumchron.cluster
      overlap = described_class.new(cluster, holding_with_enumchron.organization, htitem_with_enumchron)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(0)
    end

    it "chron is ignored for matching purposes" do
      htitem_with_enumchron.n_chron = "Aug"
      htitem_with_enumchron.n_enum_chron = "\tAug"
      holding_with_enumchron.save
      cluster = holding_with_enumchron.cluster
      overlap = described_class.new(cluster, holding_with_enumchron.organization, htitem_with_enumchron)
      expect(holding_with_enumchron.n_enum_chron).not_to eq(htitem_with_enumchron.n_enum_chron)
      expect(overlap.matching_holdings.count).to eq(1)
    end

    it "does not find holdings with the wrong enum" do
      holding_wrong_enumchron = create(:holding, ocn: c.ocns.first, enum_chron: "2", n_enum: "2")
      cluster = holding_wrong_enumchron.cluster
      overlap = described_class.new(cluster, holding_wrong_enumchron.organization, htitem_with_enumchron)
      expect(overlap.matching_holdings).to be_a(Enumerable)
      expect(overlap.matching_holdings.count).to eq(0)
    end

    it "does not find holdings if they have the wrong organization" do
      holding_with_enumchron.save
      cluster = holding_with_enumchron.cluster
      overlap = described_class.new(cluster, "not_an_org", htitem_with_enumchron)
      expect(overlap.matching_holdings.count).to eq(0)
    end
  end

  describe "#copy_count" do
    it "provides the correct copy count" do
      holding_with_enumchron.save
      holding_lost_missing.save
      cluster = holding_lost_missing.cluster
      mpo = described_class.new(cluster, holding_with_enumchron.organization, htitem_with_enumchron)
      expect(mpo.copy_count).to eq(2)
    end

    it "returns 0 copies if wrong organization" do
      holding_with_enumchron.save
      cluster = holding_with_enumchron.cluster
      mpo = described_class.new(cluster, "not_an_org", htitem_with_enumchron)
      expect(mpo.copy_count).to be(0)
    end

    it "returns 1 copy if billing_entity matches" do
      mpo = described_class.new(c, "upenn", htitem_with_enumchron)
      expect(mpo.copy_count).to be(1)
    end

    it "returns 1 copy if org has a non-matching holding" do
      nmh = create(:holding, ocn: htitem_with_enumchron.ocns.first, n_enum: "not matched")
      cluster = nmh.cluster
      mpo = described_class.new(cluster, nmh.organization, htitem_with_enumchron)
      expect(mpo.copy_count).to be(1)
    end
  end

  describe "#brt_count" do
    it "provides the correct brt count" do
      holding_brittle_withdrawn.save
      cluster = holding_brittle_withdrawn.cluster
      mpo = described_class.new(cluster, holding_brittle_withdrawn.organization, htitem_with_enumchron)
      expect(mpo.brt_count).to eq(1)
    end
  end

  describe "#wd_count" do
    it "provides the correct wd count" do
      holding_brittle_withdrawn.save
      cluster = holding_brittle_withdrawn.cluster
      mpo = described_class.new(cluster, holding_brittle_withdrawn.organization, htitem_with_enumchron)
      expect(mpo.wd_count).to eq(1)
    end
  end

  describe "#lm_count" do
    it "provides the correct lm count" do
      holding_lost_missing.save

      cluster = holding_lost_missing.cluster
      mpo = described_class.new(cluster, holding_lost_missing.organization, htitem_with_enumchron)
      expect(mpo.lm_count).to eq(1)
    end
  end

  describe "#access_count" do
    it "provides the correct access count" do
      holding_lost_missing.save
      holding_brittle_withdrawn.save

      cluster = holding_brittle_withdrawn.cluster
      mpo = described_class.new(cluster, holding_brittle_withdrawn.organization, htitem_with_enumchron)
      expect(mpo.access_count).to eq(2)
    end
  end
end
