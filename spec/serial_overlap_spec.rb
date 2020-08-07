# frozen_string_literal: true

require "serial_overlap"

RSpec.describe SerialOverlap do
  let(:c) { build(:cluster) }
  let(:ht) { build(:ht_item, ocns: c.ocns, bib_fmt: "ser", enum_chron: "") }
  let(:h) { build(:holding, ocn: c.ocns.first, organization: "umich", status: "lm") }
  let(:h2) do
    build(:holding,
          ocn: c.ocns.first,
            organization: "umich",
            condition: "brt",
            enum_chron: "V.1")
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
    it "returns 1 if there is any match" do
      c = Cluster.first
      expect(described_class.new(c, h.organization, ht).copy_count).to eq(1)
    end

    it "returns 1 if content_provider_code matches" do
      c = Cluster.first
      ht.update_attributes(content_provider_code: "different_org")
      expect(described_class.new(c, "different_org", ht).copy_count).to eq(1)
    end
  end
end
