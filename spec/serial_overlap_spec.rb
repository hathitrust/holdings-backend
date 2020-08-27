# frozen_string_literal: true

require "serial_overlap"

RSpec.describe SerialOverlap do
  let(:c) { build(:cluster) }
  let(:ht) { build(:ht_item, ocns: c.ocns, bib_fmt: "ser", enum_chron: "") }
  let(:ht2) do
    build(:ht_item,
          ocns: c.ocns,
          bib_fmt: "ser",
          enum_chron: "",
          ht_bib_key: ht.ht_bib_key)
  end
  let(:s) { build(:serial, ocns: c.ocns, record_id: ht.ht_bib_key) }
  let(:h) { build(:holding, ocn: c.ocns.first, organization: "umich", status: "lm") }
  let(:h2) do
    build(:holding,
          ocn: c.ocns.first,
            organization: "umich",
            condition: "brt",
            enum_chron: "")
  end
  let(:h3) { build(:holding, ocn: c.ocns.first, organization: "smu") }

  before(:each) do
    Cluster.each(&:delete)
    c.save
    ClusterSerial.new(s).cluster.tap(&:save)
    ClusterHtItem.new(ht).cluster.tap(&:save)
    ClusterHtItem.new(ht2).cluster.tap(&:save)
    ClusterHolding.new(h).cluster.tap(&:save)
    ClusterHolding.new(h2).cluster.tap(&:save)
    ClusterHolding.new(h3).cluster.tap(&:save)
    c.reload
  end

  describe "#copy_count" do
    it "is actually a serial" do
      expect(CalculateFormat.new(c).cluster_format).to eq("ser")
    end

    it "returns 1 if there is any match" do
      expect(described_class.new(c, h.organization, ht).copy_count).to eq(1)
    end

    it "returns 1 if content_provider_code matches" do
      ht.update_attributes(content_provider_code: "different_org")
      c.reload
      expect(described_class.new(c, "different_org", ht).copy_count).to eq(1)
    end

    it "returns 1 if any content_provider_code in the cluster matches" do
      # ht2.c_p_c will have a CC for a umich item despite no holdings
      expect(described_class.new(c, ht2.content_provider_code, ht).copy_count).to eq(1)
    end
  end
end
