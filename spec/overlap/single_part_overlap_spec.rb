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
  let(:h) { build(:holding, ocn: ht.ocns.first, organization: "umich", status: "LM") }
  let(:h2) do
    build(:holding,
      ocn: c.ocns.first,
      organization: "umich",
      condition: "BRT")
  end
  let(:h3) { build(:holding, ocn: ht.ocns.first, organization: "smu") }

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
end
