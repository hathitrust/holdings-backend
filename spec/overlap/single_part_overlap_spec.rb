# frozen_string_literal: true

require "spec_helper"
require "overlap/single_part_overlap"

RSpec.describe Overlap::SinglePartOverlap do
  include_context "with tables for holdings"

  let(:ht_item) { build(:ht_item, :spm) }

  context "when deposited but not held" do
    let(:michigan_deposited_item) do
      build(:ht_item, :spm,
        ocns: ht_item.ocns,
        collection_code: "MIU")
    end

    before(:each) { load_test_data(michigan_deposited_item) }

    it "has a copy count of 1" do
      spo = described_class.new("umich", michigan_deposited_item)
      expect(spo.copy_count).to eq(1)
    end

    it "has a current holdings count of 0" do
      spo = described_class.new("umich", michigan_deposited_item)
      expect(spo.current_holding_count).to eq(0)
    end
  end

  context "with a lost/missing holding" do
    let(:lost_missing_holding) do
      build(:holding, mono_multi_serial: "spm", ocn: ht_item.ocns.first, organization: "umich", status: "WD")
    end

    it "has no current holdings" do
      load_test_data(ht_item, lost_missing_holding)
      spo = described_class.new("umich", ht_item)
      expect(spo.current_holding_count).to eq(0)
    end
  end

  context "with three holdings" do
    let(:h) { build(:holding, mono_multi_serial: "spm", ocn: ht_item.ocns.first, organization: "umich", status: "LM") }
    let(:h2) do
      build(:holding,
        mono_multi_serial: "spm",
        ocn: ht_item.ocns.first,
        organization: "umich",
        condition: "BRT")
    end
    let(:h3) { build(:holding, mono_multi_serial: "spm", ocn: ht_item.ocns.first, organization: "smu") }

    before(:each) do
      load_test_data(ht_item, h, h2, h3)
    end

    describe "#copy_count" do
      it "provides the correct copy count" do
        spo = described_class.new(h.organization, ht_item)
        expect(spo.copy_count).to eq(2)
      end

      it "returns 1 if only billing_entity matches" do
        ht_item.billing_entity = "different_org"
        expect(described_class.new("different_org", ht_item).copy_count).to eq(1)
      end

      it "returns 0 if nothing matches" do
        expect(described_class.new("not an org", ht_item).copy_count).to eq(0)
      end
    end

    describe "#wd_count" do
      it "provides the correct wd count" do
        spo = described_class.new(h.organization, ht_item)
        expect(spo.brt_count).to eq(1)
      end
    end

    describe "#brt_count" do
      it "provides the correct brt count" do
        spo = described_class.new(h.organization, ht_item)
        expect(spo.brt_count).to eq(1)
      end
    end

    describe "#lm_count" do
      it "provides the correct lm count" do
        spo = described_class.new(h.organization, ht_item)
        expect(spo.lm_count).to eq(1)
      end
    end

    describe "#access_count" do
      it "provides the correct access count" do
        spo = described_class.new(h.organization, ht_item)
        expect(spo.access_count).to eq(2)
      end
    end

    describe "#current_holding_count" do
      it "includes brittle holdings but not lost/missing" do
        spo = described_class.new(h.organization, ht_item)
        expect(spo.current_holding_count).to eq(1)
      end
    end

    describe "#deposited_only?" do
      it "returns false if the member reports holding it" do
        spo = described_class.new(h.organization, ht_item)
        expect(spo.deposited_only?).to be false
      end

      it "returns true if the member deposited it but didn't report holding it" do
        ht_item.billing_entity = "different_org"
        expect(described_class.new("different_org", ht_item).deposited_only?).to be true
      end

      it "returns false if the member holds it but didn't deposit it" do
        expect(described_class.new("smu", ht_item).deposited_only?).to be false
      end
    end

    describe "#to_hash" do
      it "returns a hash with counts" do
        overlap_hash = described_class.new(h.organization, ht_item).to_hash
        expect(overlap_hash).to eq(volume_id: ht_item.item_id,
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
end
