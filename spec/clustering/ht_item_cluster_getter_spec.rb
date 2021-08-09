# frozen_string_literal: true

require "spec_helper"
require "clustering/ht_item_cluster_getter"

RSpec.describe Clustering::HtItemClusterGetter do
  let(:no_ocn) { build(:ht_item, ocns: []) }

  before(:each) do
    Cluster.each(&:delete)
  end

  describe "#initialize" do
    it "raises ArgumentError if given more than one htitem" do
      expect { described_class.new(double(:item1, ocns: []), double(:item2, ocns: [])) }
        .to raise_exception(ArgumentError)
    end

    it "raises ArgumentError if given an htitem with ocns" do
      expect { described_class.new(double(:item1, ocns: [1, 2, 3])) }
        .to raise_exception(ArgumentError)
    end

    it "returns when given a single OCNless htitem" do
      expect(described_class.new(double(:item1, ocns: [])))
        .not_to be(nil)
    end
  end

  describe "#get" do
    context "when a cluster with the htitem exists" do
      it "returns that cluster" do
        cluster = create(:cluster, ocns: [], ht_items: [no_ocn])

        expect(described_class.new(no_ocn).get).to eq(cluster)
      end
    end

    context "when there is no cluster with that htitem" do
      it "returns a new cluster" do
        expect { described_class.new(no_ocn).get }.to change(Cluster, :count).from(0).to(1)
      end
    end
  end
end
