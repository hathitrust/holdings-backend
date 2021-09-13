# frozen_string_literal: true

require "spec_helper"
require "calculate_format"

RSpec.describe CalculateFormat do
  let(:ht_spm) { build(:ht_item, :spm) }
  let(:ht_mpm) { build(:ht_item, :mpm) }
  let(:ht_ser) { build(:ht_item, :ser) }
  let(:c) { create(:cluster, ocns: ht_spm.ocns) }

  describe "#item_format" do
    it "defaults to SPM" do
      expect(described_class.new(c).item_format(ht_spm)).to eq("spm")
    end

    it "is a MPM if it or another item has enum" do
      c_mpm = Clustering::ClusterHtItem.new(ht_mpm).cluster
      expect(
        described_class.new(c_mpm).item_format(ht_mpm)
      ).to eq("mpm")
    end

    it "is NOT an MPM if it has a chron but no enum" do
      ht_chron = build(:ht_item, bib_fmt: "BK", enum_chron: "1994")
      c_chron = Clustering::ClusterHtItem.new(ht_chron).cluster
      expect(
        described_class.new(c_chron).item_format(ht_chron)
      ).to eq("spm")
    end

    it "is a MPM if another ht item on this record has enum" do
      ht_spm.ht_bib_key = ht_mpm.ht_bib_key
      c.ht_items << ht_mpm
      c.ht_items << ht_spm
      expect(described_class.new(c).item_format(ht_spm)).to eq("mpm")
    end

    it "is NOT an MPM just because another ht item in the cluster has an enum" do
      ht_spm.ht_bib_key = "not ht_mpm's bib key"
      c.ht_items << ht_mpm
      c.ht_items << ht_spm
      expect(described_class.new(c).item_format(ht_spm)).to eq("spm")
    end

    it "is a SER if the htitem has bibformat SE" do
      expect(described_class.new(c).item_format(ht_ser)).to eq("ser")
      c.ht_items << ht_ser
      expect(
        described_class.new(c).item_format(c.ht_items.first)
      ).to eq("ser")
    end

    it "is a SER if it is in the list of large cluster ocns" do
      c_mpm = Clustering::ClusterHtItem.new(ht_mpm).cluster
      Services.large_clusters.ocns.add(ht_mpm.ocns.first)
      expect(described_class.new(c_mpm).item_format(ht_mpm)).to eq("ser")
    end

    it "MPM's don't clobber Serials just yet" do
      c.ht_items << ht_ser
      c.ht_items << ht_mpm
      expect(
        described_class.new(c).item_format(c.ht_items.first)
      ).to eq("ser")
      expect(
        described_class.new(c).item_format(c.ht_items.last)
      ).to eq("mpm")
    end
  end

  describe "#cluster_format" do
    it "is a MPM if any items are MPM" do
      c.ht_items << ht_mpm
      c.ht_items << ht_spm
      c.ht_items << ht_ser
      expect(described_class.new(c).cluster_format).to eq("mpm")
    end

    it "is a SPM if all items are SPM" do
      c.ht_items << ht_spm
      expect(described_class.new(c).cluster_format).to eq("spm")
    end

    it "is a SER if all items are SER" do
      c.ht_items << ht_ser
      expect(described_class.new(c).cluster_format).to eq("ser")
    end

    it "is a SER/SPM if some items are SER and some are SPM" do
      c.ht_items << ht_spm
      c.ht_items << ht_ser
      expect(described_class.new(c).cluster_format).to eq("ser/spm")
    end
  end
end
