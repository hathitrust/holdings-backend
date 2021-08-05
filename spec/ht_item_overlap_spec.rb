# frozen_string_literal: true

require "spec_helper"
require "ht_item_overlap"

RSpec.describe HtItemOverlap do
  let(:c) { build(:cluster) }
  let(:mpm) do
    build(:ht_item,
          ocns: c.ocns,
          enum_chron: "1",
          n_enum: "1",
          billing_entity: "ucr")
  end
  let(:holding) do
    build(:holding,
          ocn: c.ocns.first,
          organization: "umich",
          enum_chron: "1",
          n_enum: "1")
  end
  let(:holding2) do
    build(:holding,
          ocn: c.ocns.first,
            organization: "smu",
            enum_chron: "1",
            n_enum: "1")
  end
  let(:non_match_holding) do
    build(:holding,
          ocn: c.ocns.first,
        organization: "stanford",
        enum_chron: "2",
        n_enum: "2")
  end

  before(:each) do
    Cluster.each(&:delete)
    c.save
    Clustering::ClusterHtItem.new(mpm).cluster.tap(&:save)
    Clustering::ClusterHolding.new(holding).cluster.tap(&:save)
    Clustering::ClusterHolding.new(holding2).cluster.tap(&:save)
    Clustering::ClusterHolding.new(non_match_holding).cluster.tap(&:save)
  end

  describe "#organizations_with_holdings" do
    it "returns all organizations that overlap with an item" do
      c.reload
      overlap = described_class.new(c.ht_items.first)
      # billing_entity: ucr, holdings: smu, umich, non_matching: stanford
      expect(overlap.organizations_with_holdings.count).to eq(4)
    end

    it "member should match mpm if none of their holdings match" do
      c.reload
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.organizations_with_holdings).to include("stanford")
    end

    it "does not include non-matching organizations that match something else" do
      mpm2 = build(:ht_item,
                   ocns: c.ocns,
                   enum_chron: "2",
                   n_enum: "2",
                   billing_entity: "ucr")
      Clustering::ClusterHtItem.new(mpm2).cluster.tap(&:save)
      c.reload
      overlap = described_class.new(c.ht_items.where(n_enum: "2").first)
      expect(overlap.ht_item.n_enum).to eq("2")
      expect(overlap.organizations_with_holdings).not_to include("umich")
    end

    it "only returns unique organizations" do
      Clustering::ClusterHolding.new(holding).cluster.tap(&:save)
      c.reload
      expect(CalculateFormat.new(c).cluster_format).to eq("mpm")
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.organizations_with_holdings.count).to eq(4)
    end

    it "matches if holding enum is ''" do
      empty_holding = build(:holding,
                            ocn: c.ocns.first,
                            organization: "upenn",
                            enum_chron: "",
                            n_enum: "")
      Clustering::ClusterHolding.new(empty_holding).cluster.tap(&:save)
      c.reload
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.organizations_with_holdings).to include("upenn")
    end

    it "matches if holding enum is '', but chron exists" do
      almost_empty_holding = build(:holding,
                                   ocn: c.ocns.first,
                                   organization: "upenn",
                                   enum_chron: "Aug",
                                   n_enum: "",
                                   n_chron: "Aug")
      Clustering::ClusterHolding.new(almost_empty_holding).cluster.tap(&:save)
      c.reload
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.organizations_with_holdings).to include("upenn")
    end

    it "does not match if ht item enum is ''" do
      empty_mpm = build(:ht_item,
                        ocns: c.ocns,
                         billing_entity: "ucr",
                         enum_chron: "",
                         n_enum: "")
      Clustering::ClusterHtItem.new(empty_mpm).cluster.tap(&:save)
      c.reload
      overlap = described_class.new(c.ht_items.where(enum_chron: "").first)
      expect(overlap.organizations_with_holdings).to eq([non_match_holding.organization,
                                                         empty_mpm.billing_entity])
    end
  end

  describe "#h_share" do
    let(:keio_item) do
      build(:ht_item,
            ocns: c.ocns,
            collection_code: "KEIO",
            enum_chron: "1")
    end

    let(:ucm_item) do
      build(:ht_item,
            ocns: c.ocns,
            collection_code: "UCM",
            enum_chron: "1")
    end

    it "returns ratio of organizations" do
      c.reload
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.h_share("umich")).to eq(1.0 / 4)
    end

    it "assigns an h_share to hathitrust for KEIO items" do
      Clustering::ClusterHtItem.new(keio_item).cluster.tap(&:save)
      c.reload
      overlap = described_class.new(c.ht_items.last)
      expect(c.ht_items.last.billing_entity).to eq("hathitrust")
      expect(overlap.h_share("hathitrust")).to eq(1.0 / 4)
      expect(overlap.h_share("umich")).to eq(1.0 / 4)
    end

    it "assigns an h_share to UCM as it would anyone else" do
      Clustering::ClusterHtItem.new(ucm_item).cluster.tap(&:save)
      c.reload
      overlap = described_class.new(c.ht_items.last)
      expect(c.ht_items.last.billing_entity).to eq("ucm")
      expect(overlap.h_share("ucm")).to eq(1.0 / 4)
      expect(overlap.h_share("umich")).to eq(1.0 / 4)
    end

    it "returns 0 if not held" do
      c.reload
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.h_share("upenn")).to eq(0)
    end
  end
end
