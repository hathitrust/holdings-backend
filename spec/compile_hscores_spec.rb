# frozen_string_literal: true

require "cluster"
require_relative "../bin/compile_hscores"

RSpec.describe "compile_hscores" do
  let(:h) { build(:holding) }
  let(:ht) { build(:ht_item, ocns: [h.ocn], content_provider_code: "not_same_as_holding") }
  let(:ht2) { build(:ht_item, content_provider_code: "not_same_as_holding") }

  before(:each) do
    Cluster.each(&:delete)
    ClusterHolding.new(h).cluster.tap(&:save)
    ClusterHtItem.new(ht).cluster.tap(&:save)
    ClusterHtItem.new(ht2).cluster.tap(&:save)
  end

  describe "#matching_clusters" do
    it "finds them all if org is nil" do
      expect(matching_clusters.count).to eq(2)
    end

    it "finds by holding" do
      expect(matching_clusters(h.organization).count).to eq(1)
    end

    it "finds by ht_item" do
      expect(matching_clusters(ht.content_provider_code).count).to eq(2)
    end
  end

  describe "#compile_total_hscore" do
    let(:freq) { { umich: { 1 => 5, 2 => 3, 3 => 1 }, smu: { 1 => 2, 2 => 1 } } }

    it "compiles the total hscore" do
      expect(compile_total_hscore(freq)[:umich]).to \
        be_within(0.0001).of(5.0 / 1.0 + 3.0 / 2.0 + 1.0 / 3.0)
      expect(compile_total_hscore(freq)[:smu]).to \
        be_within(0.0001).of(2.0 / 1.0 + 1.0 / 2.0)
    end
  end
end
