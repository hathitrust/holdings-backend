# frozen_string_literal: true

require "spec_helper"
require "calculate_format"

RSpec.describe CalculateFormat do
  let(:ht_spm) { build(:ht_item, :spm) }
  let(:ht_mpm) { build(:ht_item, :mpm) }
  let(:ht_ser) { build(:ht_item, :ser) }

  include_context "with tables for holdings"

  describe "#item_format" do
    it "defaults to SPM" do
      insert_htitem ht_spm
      c = ht_spm.cluster
      expect(described_class.new(c).item_format(ht_spm)).to eq("spm")
    end

    it "is a MPM if it or another item has enum" do
      insert_htitem ht_mpm
      c = ht_mpm.cluster
      expect(
        described_class.new(c).item_format(ht_mpm)
      ).to eq("mpm")
    end

    it "is NOT an MPM if it has a chron but no enum" do
      ht_chron = build(:ht_item, bib_fmt: "BK", enum_chron: "1994")
      insert_htitem ht_chron
      c = ht_chron.cluster
      expect(
        described_class.new(c).item_format(ht_chron)
      ).to eq("spm")
    end

    it "is NOT an MPM with null n_enum" do
      htitem = double(:htitem, ht_bib_key: "12345", bib_fmt: "BK", n_enum: nil)
      cluster = double(:cluster, ht_items: [htitem])

      expect(
        described_class.new(cluster).item_format(htitem)
      ).to eq("spm")
    end

    it "is NOT an MPM with empty string n_enum" do
      htitem = double(:htitem, ht_bib_key: "12345", bib_fmt: "BK", n_enum: "")
      cluster = double(:cluster, ht_items: [htitem])

      expect(
        described_class.new(cluster).item_format(htitem)
      ).to eq("spm")
    end

    it "is a MPM if another ht item on this record has enum" do
      ht_spm.ht_bib_key = ht_mpm.ht_bib_key
      ht_spm.ocns = ht_mpm.ocns
      insert_htitem ht_spm
      insert_htitem ht_mpm
      c = ht_spm.cluster
      expect(described_class.new(c).item_format(ht_spm)).to eq("mpm")
    end

    it "is NOT an MPM just because another ht item in the cluster has an enum" do
      ht_spm.ht_bib_key = ht_mpm.ht_bib_key + 1
      ht_spm.ocns = ht_mpm.ocns
      insert_htitem ht_spm
      insert_htitem ht_mpm
      c = ht_spm.cluster
      expect(described_class.new(c).item_format(ht_spm)).to eq("spm")
    end

    it "is a SER if the htitem has bibformat SE" do
      insert_htitem ht_ser
      c = ht_ser.cluster
      expect(described_class.new(c).item_format(ht_ser)).to eq("ser")
      expect(
        described_class.new(c).item_format(c.ht_items.first)
      ).to eq("ser")
    end

    it "MPM's don't clobber Serials just yet" do
      ht_ser.ocns = ht_mpm.ocns
      insert_htitem ht_ser
      insert_htitem ht_mpm
      c = ht_ser.cluster
      expect(
        described_class.new(c).item_format(ht_ser)
      ).to eq("ser")
      expect(
        described_class.new(c).item_format(ht_mpm)
      ).to eq("mpm")
    end
  end

  describe "#cluster_format" do
    it "is a MPM if any items are MPM" do
      ht_mpm.ocns = ht_spm.ocns = ht_ser.ocns
      insert_htitem ht_mpm
      insert_htitem ht_spm
      insert_htitem ht_ser
      c = ht_mpm.cluster
      expect(described_class.new(c).cluster_format).to eq("mpm")
    end

    it "is a SPM if all items are SPM" do
      insert_htitem ht_spm
      c = ht_spm.cluster
      expect(described_class.new(c).cluster_format).to eq("spm")
    end

    it "is a SER if all items are SER" do
      insert_htitem ht_ser
      c = ht_ser.cluster
      expect(described_class.new(c).cluster_format).to eq("ser")
    end

    it "is a SER/SPM if some items are SER and some are SPM" do
      ht_spm.ocns = ht_ser.ocns
      insert_htitem ht_spm
      insert_htitem ht_ser
      c = ht_spm.cluster
      expect(described_class.new(c).cluster_format).to eq("ser/spm")
    end
  end
end
