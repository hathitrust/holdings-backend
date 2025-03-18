# frozen_string_literal: true

require "spec_helper"
require "overlap/overlap_table_update"

RSpec.xdescribe Overlap::OverlapTableUpdate do
  let(:update) { described_class.new(nil, 10) }

  before(:each) do |_spec|
    h = build(:holding)
    ht = build(:ht_item, :spm, ocns: [h.ocn], billing_entity: "not_same_as_holding")
    ht2 = build(:ht_item, :spm, billing_entity: "not_same_as_holding")
    Cluster.each(&:delete)
    Clustering::ClusterHolding.new(h).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht2).cluster.tap(&:save)

    Services.register(:holdings_db) { DataSources::HoldingsDB.connection }
    Services.register(:relational_overlap_table) { Services.holdings_db[:holdings_htitem_htmember] }
    Services.relational_overlap_table.delete
  end

  describe "#overlap_table" do
    it "gets us the holdings_htitem_htmember table" do
      expect(update.overlap_table.count).to eq(0)
    end
  end
end
