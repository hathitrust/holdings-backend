# frozen_string_literal: true

require "spec_helper"
require "overlap/single_part_overlap"

RSpec.describe Overlap::SinglePartOverlap do
  include_context "with tables for holdings"

  let(:ht) { build(:ht_item, :spm) }
  let(:c) { Cluster.new(ocns: ht.ocns) }
  let(:ht2) do
    build(:ht_item, :spm,
      ocns: ht.ocns,
      collection_code: "MIU")
  end
  let(:h) { build(:holding, mono_multi_serial: "spm", ocn: ht.ocns.first, organization: "umich", status: "LM") }
  let(:h2) do
    build(:holding,
      mono_multi_serial: "spm",
      ocn: c.ocns.first,
      organization: "umich",
      condition: "BRT")
  end
  let(:h3) { build(:holding, mono_multi_serial: "spm", ocn: ht.ocns.first, organization: "smu") }

  before(:each) do
    load_test_data(ht, h, h2, h3)
  end

  describe "#copy_count" do
    it "provides the correct copy count" do
      spo = described_class.new(h.organization, ht)
      expect(spo.copy_count).to eq(2)
    end

    it "returns 1 if only billing_entity matches" do
      ht.billing_entity = "different_org"
      expect(described_class.new("different_org", ht).copy_count).to eq(1)
    end

    it "returns 0 if nothing matches" do
      expect(described_class.new("not an org", ht).copy_count).to eq(0)
    end
  end

  describe "#wd_count" do
    it "provides the correct wd count" do
      spo = described_class.new(h.organization, ht)
      expect(spo.brt_count).to eq(1)
    end
  end

  describe "#brt_count" do
    it "provides the correct brt count" do
      spo = described_class.new(h.organization, ht)
      expect(spo.brt_count).to eq(1)
    end
  end

  describe "#lm_count" do
    it "provides the correct lm count" do
      spo = described_class.new(h.organization, ht)
      expect(spo.lm_count).to eq(1)
    end
  end

  describe "#access_count" do
    it "provides the correct access count" do
      spo = described_class.new(h.organization, ht)
      expect(spo.access_count).to eq(2)
    end
  end

  describe "#deposited_only?" do
    it "returns false if the member reports holding it" do
      spo = described_class.new(h.organization, ht)
      expect(spo.deposited_only?).to be false
    end

    it "returns true if the member deposited it but didn't report holding it" do
      ht.billing_entity = "different_org"
      expect(described_class.new("different_org", ht).deposited_only?).to be true
    end

    it "returns false if the member holds it but didn't deposit it" do
      expect(described_class.new("smu", ht).deposited_only?).to be false
    end
  end

  describe "#to_hash" do
    it "returns a hash with counts" do
      overlap_hash = described_class.new(h.organization, ht).to_hash
      expect(overlap_hash).to eq(volume_id: ht.item_id,
        member_id: h.organization,
        n_enum: "",
        # Counts are overridden by subclasses
        copy_count: 2,
        brt_count: 1,
        wd_count: 0,
        lm_count: 1,
        # number of holdings with brittle or lost/missing
        access_count: 2,
        # not withdrawn/lost/missing
        current_holding_count: 1,
        deposited_only: false)
    end
  end
end
