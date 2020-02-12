# frozen_string_literal: true

require "mongo_cluster"

RSpec.describe MongoCluster do
  let(:id) { 1 }

  #  before(:each) { Services.cluster_collection.drop }
  let(:collection) { double(:collection) }

  around(:each) do |example|
    old_coll = Services.cluster_collection
    Services.register(:cluster_collection) { collection }
    example.run
    Services.register(:cluster_collection) { old_coll }
  end

  def find(id)
    described_class.find_by_member(id)
  end

  describe "#new" do
    it "returns a cluster" do
      expect(described_class.new(id)).to be_a(described_class)
    end

    it "does not persist the cluster" do
      described_class.new(id)
      expect(collection).not_to receive(:replace_one)
    end
  end

  describe "#save" do
    it "serializes a cluster and its members" do
      expect(collection).to receive(:replace_one).with(
        { _id: anything },
        { _id: anything, members: [1, 2, 3] },
        upsert: true
)

      described_class.new(1, 2, 3).save
    end

    it "can edit an existing cluster" do
      allow(collection).to receive(:replace_one)
      expect(collection).to receive(:replace_one).with(
        { _id: anything },
        { _id: anything, members: [1, 2, 3] },
        upsert: true
)

      described_class.new(1, 2).save.add(3).save
    end
  end

  describe "#find_by_member" do
    it "tries to find the id in the collection" do
      expect(collection).to receive(:find).with(members: 1).and_return([])

      described_class.find_by_member(1)
    end
  end

  describe "#delete" do
    it "deletes a cluster" do
      cluster = described_class.new
      expect(collection).to receive(:delete_one).with(_id: cluster._id)

      cluster.delete
    end
  end
end
