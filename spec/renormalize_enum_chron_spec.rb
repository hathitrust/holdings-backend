# frozen_string_literal: true

require "spec_helper"
require "cluster_holding"
require_relative "../bin/renormalize_enumchrons"

RSpec.describe "Renormalize Enumchrons" do
  let(:h) { build(:holding, enum_chron: "1") }

  before(:each) do
    Cluster.each(&:delete)
    h.n_enum_chron = nil
    ClusterHolding.new(h).cluster.tap(&:save)
  end

  describe "#renormalize" do
    it "re-extracts from the enum_chron field" do
      c = Cluster.first
      h = c.holdings.first
      expect(h.n_enum_chron).to be_nil

      renormalize(h)
      expect(h.n_enum_chron).to eq("1\t")
    end
  end

  describe "#records_with_enum_chrons" do
    it "find holdings and ht items with enum chrons" do
      ht = build(:ht_item, enum_chron: "1", ocns: [h.ocn])
      ht.n_enum_chron = nil
      ClusterHtItem.new(ht).cluster.tap(&:save)
      expect(records_with_enum_chrons.each.to_a.size).to eq(2)
      expect(records_with_enum_chrons.count(&:n_enum_chron)).to eq(0)
      records_with_enum_chrons {|i| renormalize(i) }
      expect(records_with_enum_chrons.count(&:n_enum_chron)).to eq(2)
    end
  end
end
