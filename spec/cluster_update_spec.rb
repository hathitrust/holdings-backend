# frozen_string_literal: true

require "spec_helper"
require "cluster_update"
require "overlap/overlap_table_update"

RSpec.xdescribe ClusterUpdate do
  let(:update) { Overlap::OverlapTableUpdate.new }
  let(:h) { build(:holding, organization: "upenn") }
  let(:ht) { build(:ht_item, :spm, ocns: [h.ocn], billing_entity: "not_same_as_holding") }
  let(:ht2) { build(:ht_item, :spm, billing_entity: "not_same_as_holding") }

  before(:each) do |_spec|
    Cluster.each(&:delete)
    Clustering::ClusterHolding.new(h).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht2).cluster.tap(&:save)

    Services.register(:holdings_db) { DataSources::HoldingsDB.connection }
    Services.register(:relational_overlap_table) { Services.holdings_db[:holdings_htitem_htmember] }
    Services.relational_overlap_table.delete
  end

  describe "#deletes" do
    it "has the list of overlap records to delete" do
      cfirst = Cluster.first
      described_class.new(update.overlap_table, cfirst).upsert
      expect(update.overlap_table.count).to eq(2)
      deleted_rec = update.overlap_table.filter(member_id: cfirst.holdings.first.organization).first
      cfirst.holdings.each(&:delete)
      cfirst.save
      cu = described_class.new(update.overlap_table, Cluster.first)
      expect(cu.deletes.count).to eq(1)
      expect(cu.deletes).to eq([deleted_rec])
    end
  end

  describe "#adds" do
    it "has the list of overlap records to add" do
      cfirst = Cluster.first
      described_class.new(update.overlap_table, cfirst).upsert

      h = build(:holding, organization: "smu", ocn: cfirst.ocns.first)
      Clustering::ClusterHolding.new(h).cluster.tap(&:save)
      cfirst = Cluster.first
      cu = described_class.new(update.overlap_table, cfirst)
      expect(cu.new_overlaps.count).to eq(3)
      expect(cu.adds.count).to eq(1)
    end
  end

  describe "#existing_overlaps" do
    it "has the list of overlap records already in the database" do
      described_class.new(update.overlap_table, Cluster.first).upsert
      cu = described_class.new(update.overlap_table, Cluster.first)
      expect(cu.existing_overlaps.count).to eq(2)
      expect(cu.existing_overlaps).to eq(update.overlap_table.to_a)
    end
  end

  describe "#upsert" do
    it "adds a new overlap to the table" do
      described_class.new(update.overlap_table, Cluster.first).upsert
      expect(update.overlap_table.count).to eq(2)
    end

    it "updates an existing overlap in the table" do
      expect(update.overlap_table.count).to eq(0)
      cfirst = Cluster.first
      described_class.new(update.overlap_table, cfirst).upsert
      expect(update.overlap_table.count).to eq(2)
      cfirst.holdings.each(&:delete)
      cfirst.save
      cu = described_class.new(update.overlap_table, Cluster.first)
      cu.upsert
      expect(update.overlap_table.count).to eq(1)
    end

    it "does not churn the database" do
      described_class.new(update.overlap_table, Cluster.first).upsert
      existing_overlaps = update.overlap_table.filter(cluster_id: Cluster.first._id.to_s)
      mock_table = double("overlap_table")
      allow(mock_table).to receive(:filter).and_return(existing_overlaps)
      allow(mock_table).to receive(:insert)
      allow(mock_table).to receive(:delete)

      expect(update.overlap_table.count).to eq(2)
      expect(mock_table).to receive(:delete).exactly(0).times
      expect(mock_table).to receive(:insert).exactly(0).times
      described_class.new(mock_table, Cluster.first).upsert
    end
  end

  context "with ht moving clusters" do
    let(:new_holding) { build(:holding) }
    let(:updated_item) do
      build(:ht_item, item_id: ht.item_id,
        ocns: [new_holding.ocn], billing_entity: "not_same_as_holding")
    end

    before(:each) do
      Clustering::ClusterHolding.new(new_holding).cluster.tap(&:save)
      cfirst = Cluster.find_by(ocns: ht.ocns.first)
      described_class.new(update.overlap_table, cfirst).upsert
    end

    it "does not remove the old overlap record" do
      expect(update.overlap_table.count).to eq(2)
      cfirst = Cluster.find_by(ocns: ht.ocns.first)
      Clustering::ClusterHtItem.new(updated_item).cluster.tap(&:save)
      cfirst = Cluster.where(_id: cfirst._id).first
      # cfirst no longer has any ht_items
      cu = described_class.new(update.overlap_table, cfirst)
      expect(cu.deletes.count).to eq(0)
      cu.upsert
      expect(update.overlap_table.count).to eq(2)
    end

    it "the new cluster removes/updates the old overlap record" do
      expect(update.overlap_table.count).to eq(2)
      Clustering::ClusterHtItem.new(updated_item).cluster.tap(&:save)
      new_cluster = Cluster.find_by(ocns: updated_item.ocns)
      cu = described_class.new(update.overlap_table, new_cluster)
      # expect(cu.existing_overlaps.count).to eq(2)
      # expect(cu.new_overlaps.count).to eq(2)
      # expect(cu.adds.count).to eq(2) # change in cluster id and member
      # expect(cu.deletes.count).to eq(2)
      cu.upsert
      expect(update.overlap_table.count).to eq(2)
    end
  end
end
