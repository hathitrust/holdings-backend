# frozen_string_literal: true

require "single_part_overlap"

RSpec.describe SinglePartOverlap do
  let(:c) { build(:cluster) }
  let(:ht) { build(:ht_item, ocns: c.ocns, bib_fmt: "spm", enum_chron: "") }
  let(:ht2) do
    build(:ht_item,
          ocns: c.ocns,
          bib_fmt: "spm",
          enum_chron: "",
          content_provider_code: "yet_another_org")
  end
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
    c.reload
  end

  describe "#copy_count" do
    it "provides the correct copy count" do
      spo = described_class.new(c, h.organization, ht)
      expect(spo.copy_count).to eq(2)
    end

    it "returns 1 if only content_provider_code matches" do
      ht.update_attributes(content_provider_code: "different_org")
      c.reload
      expect(described_class.new(c, "different_org", ht).copy_count).to eq(1)
    end

    it "returns 1 if any content_provider_code in the cluster matches" do
      ClusterHtItem.new(ht2).cluster.tap(&:save)
      c.reload
      # ht2.c_p_c will have a CC for a umich item despite no holdings
      expect(described_class.new(c, ht2.content_provider_code, ht).copy_count).to eq(1)
    end

    it "returns 0 if nothing matches" do
      expect(described_class.new(c, "not an org", ht).copy_count).to eq(0)
    end
  end

  describe "#wd_count" do
    it "provides the correct wd count" do
      spo = described_class.new(c, h.organization, ht)
      expect(spo.brt_count).to eq(1)
    end
  end

  describe "#brt_count" do
    it "provides the correct brt count" do
      spo = described_class.new(c, h.organization, ht)
      expect(spo.brt_count).to eq(1)
    end
  end

  describe "#lm_count" do
    it "provides the correct lm count" do
      spo = described_class.new(c, h.organization, ht)
      expect(spo.lm_count).to eq(1)
    end
  end

  describe "#access_count" do
    it "provides the correct access count" do
      spo = described_class.new(c, h.organization, ht)
      expect(spo.access_count).to eq(2)
    end
  end
end
