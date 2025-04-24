# frozen_string_literal: true

require "spec_helper"
require "overlap/serial_overlap"

RSpec.describe Overlap::SerialOverlap do
  include_context "with tables for holdings"

  let(:c) { build(:cluster) }

  # items from upenn
  let(:ht) { build(:ht_item, :ser, ocns: c.ocns, collection_code: "PU") }
  let(:ht2) { build(:ht_item, :ser, ocns: c.ocns, ht_bib_key: ht.ht_bib_key, collection_code: "PU") }

  # michigan holdings
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
    load_test_data(ht, ht2, h, h2, h3)
  end

  describe "#copy_count" do
    it "is actually a serial" do
      expect(CalculateFormat.new(c).cluster_format).to eq("ser")
    end

    it "returns 1 if there is any holding match" do
      expect(described_class.new("umich", ht).copy_count).to eq(1)
    end

    it "returns 1 if billing_entity matches" do
      expect(described_class.new("upenn", ht).copy_count).to eq(1)
    end
  end
end
