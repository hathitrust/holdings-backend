# frozen_string_literal: true

require "spec_helper"
require "cluster_getter"

RSpec.describe Clustering::ClusterGetter do
  let(:ocn1) { 5 }
  let(:ocn2) { 6 }
  let(:ocn3) { 7 }
  let(:ocn4) { 8 }
  let(:ht) { build(:ht_item).to_hash }

  before(:each) do
    Cluster.create_indexes
    Cluster.collection.find.delete_many
  end

  context "when merging two clusters" do
    let(:c1) { create(:cluster, ocns: [ocn1]) }
    let(:c2) { create(:cluster, ocns: [ocn2]) }
    let(:htitem1) { build(:ht_item, ocns: [ocn1]).to_hash }
    let(:htitem2) { build(:ht_item, ocns: [ocn2]).to_hash }
    let(:holding1) { build(:holding, ocn: ocn1).attributes }
    let(:holding2) { build(:holding, ocn: ocn2).attributes }
    let(:ocn_resolution1) { build(:ocn_resolution, resolved: ocn1, deprecated: ocn3).attributes }
    let(:ocn_resolution2) { build(:ocn_resolution, resolved: ocn2, deprecated: ocn4).attributes }

    let(:merged_cluster) { described_class.new([ocn1, ocn2]).get }

    it "combines ocns sets" do
      c1
      c2
      expect(merged_cluster.ocns).to contain_exactly(ocn1, ocn2)
    end

    it "combines holdings" do
      c1.holdings.create(holding1)
      c2.holdings.create(holding2)
      expect(merged_cluster.holdings.count).to eq(2)
    end

    it "combines OCN resolution rules" do
      c1.ocns = [ocn1, ocn3]
      c1.ocn_resolutions.create(ocn_resolution1)
      c1.save

      c2.ocns = [ocn2, ocn4]
      c2.ocn_resolutions.create(ocn_resolution2)
      c2.save

      expect(merged_cluster.ocn_resolutions.count).to eq(2)
    end

    it "adds OCNs that were in neither cluster" do
      c1
      c2
      expect(described_class.new([ocn1, ocn2, ocn3]).get.ocns)
        .to contain_exactly(ocn1, ocn2, ocn3)
    end

    it "combines ht_items" do
      c1.ht_items.create(htitem1)
      c2.ht_items.create(htitem2)
      expect(merged_cluster.ht_items.count).to eq(2)
    end

    xit "combines and dedupes commitments" do
      c1.commitments.create(organization: "nypl")
      c2.commitments.create(organization: "nypl")
      c2.commitments.create(organization: "miu")
      expect(merged_cluster.commitments.count).to eq(2)
    end
  end

  context "when merging >2 clusters" do
    let(:c1) { create(:cluster, ocns: [ocn1]) }
    let(:c2) { create(:cluster, ocns: [ocn2]) }
    let(:c3) { create(:cluster, ocns: [ocn3]) }

    it "combines multiple clusters" do
      c1
      c2
      c3
      expect(Cluster.count).to eq(3)
      expect(described_class.new([ocn1, ocn2, ocn3]).get.ocns).to eq([ocn1, ocn2, ocn3])
      expect(Cluster.count).to eq(1)
    end
  end
end
