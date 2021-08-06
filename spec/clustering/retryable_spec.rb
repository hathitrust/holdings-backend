# frozen_string_literal: true

require "spec_helper"
require "services"
require "cluster"
require "retryable"
require "cluster_error"
require "clustering/cluster_ht_item"

RSpec.describe Clustering::Retryable do
  before(:each) do
    Cluster.create_indexes
    Cluster.collection.find.delete_many
  end

  describe "#with_transaction" do
    let(:htitem) { build(:ht_item) }
    let(:htitem2) { build(:ht_item, ocns: htitem.ocns) }
    let!(:cluster) do
      create(:cluster,
             ocns: htitem.ocns,
             ht_items: [htitem, htitem2])
    end

    def update_htitem
      # HTItem will move to new cluster
      htitem.ocns = htitem.ocns.map {|o| o + 1 }
      Clustering::ClusterHtItem.new(htitem).cluster
    end

    it "rolls back changes when transaction fails" do
      begin
        described_class.with_transaction do
          update_htitem
          raise "abort transaction"
        end
      rescue RuntimeError
        # transaction should be aborted
      end

      expect(Cluster.with_ht_item(htitem).first._id).to eq(cluster._id)
      expect(Cluster.count).to eq(1)
    end

    it "persists changes when transaction succeeds" do
      described_class.with_transaction do
        update_htitem
      end

      expect(Cluster.with_ht_item(htitem).first._id).not_to eq(cluster._id)
      expect(Cluster.count).to eq(2)
    end

    it "is only in a transaction inside the given block" do
      described_class.with_transaction do
        expect(Mongoid::Threaded.get_session&.in_transaction?).to be_truthy
      end

      expect(Mongoid::Threaded.get_session&.in_transaction?).to be_falsey
    end

    it "catches ClusterError, retries, and succeeds" do
      raised = false

      described_class.with_transaction do
        update_htitem
        unless raised
          raised = true
          raise ClusterError, "retry testing"
        end
      end

      expect(Cluster.with_ht_item(htitem).first._id).not_to eq(cluster._id)
      expect(Cluster.count).to eq(2)
    end
  end
end
