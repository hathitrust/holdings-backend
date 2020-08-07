# frozen_string_literal: true

require "single_part_overlap"

RSpec.describe SinglePartOverlap do
  let(:c) { build(:cluster) }
  let(:ht) { build(:ht_item, ocns: c.ocns, bib_fmt: "spm", enum_chron: "") }
  let(:h) { build(:holding, ocn: c.ocns.first, organization: "umich", status: "lm") }
  let(:h2) do
    build(:holding,
          ocn: c.ocns.first,
            organization: "umich",
            condition: "brt")
  end
  let(:h3) { build(:holding, ocn: c.ocns.first, organization: "smu") }

  before(:each) do
    Cluster.each(&:delete)
    c.save
    ClusterHtItem.new(ht).cluster.tap(&:save)
    ClusterHolding.new(h).cluster.tap(&:save)
    ClusterHolding.new(h2).cluster.tap(&:save)
    ClusterHolding.new(h3).cluster.tap(&:save)
  end

  describe "#copy_count" do
    it "provides the correct copy count" do
      c = Cluster.first
      spo = described_class.new(c, h.organization, ht)
      expect(spo.copy_count).to eq(2)
    end

    it "returns 1 if only content_provider_code matches" do
      c = Cluster.first
      ht.update_attributes(content_provider_code: "different_org")
      expect(described_class.new(c, "different_org", ht).copy_count).to eq(1)
    end

    it "returns 0 if nothing matches" do
      c = Cluster.first
      expect(described_class.new(c, "not an org", ht).copy_count).to eq(0)
    end
  end

  describe "#wd_count" do
    it "provides the correct wd count" do
      c = Cluster.first
      spo = described_class.new(c, h.organization, ht)
      expect(spo.brt_count).to eq(1)
    end
  end

  describe "#brt_count" do
    it "provides the correct brt count" do
      c = Cluster.first
      spo = described_class.new(c, h.organization, ht)
      expect(spo.brt_count).to eq(1)
    end
  end

  describe "#lm_count" do
    it "provides the correct lm count" do
      c = Cluster.first
      spo = described_class.new(c, h.organization, ht)
      expect(spo.lm_count).to eq(1)
    end
  end

  describe "#access_count" do
    it "provides the correct access count" do
      c = Cluster.first
      spo = described_class.new(c, h.organization, ht)
      expect(spo.access_count).to eq(2)
    end
  end
end
