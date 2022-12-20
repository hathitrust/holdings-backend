# frozen_string_literal: true

require "spec_helper"
require "mongo_updater"
require "shared_print/finder"

RSpec.describe MongoUpdater do
  let(:ocn1) { 1 }
  let(:ocn2) { 2 }
  let(:org1) { "umich" }
  let(:loc1) { "i111" }
  let(:loc2) { "i222" }
  let(:loc3) { "i333" }
  let(:loc4) { "i444" }
  let(:spc1) { build(:commitment, ocn: ocn1, organization: org1, local_id: loc1) }
  let(:spc2) { build(:commitment, ocn: ocn1, organization: org1, local_id: loc2) }
  let(:spc3) { build(:commitment, ocn: ocn2, organization: org1, local_id: loc3) }
  let(:spc4) { build(:commitment, ocn: ocn2, organization: org1, local_id: loc4) }
  let(:foo) { "foo" }
  let(:bar) { "bar" }
  before(:each) do
    Cluster.collection.find.delete_many
  end

  def commitment_local_ids(ocn)
    SharedPrint::Finder.new(ocn: [ocn]).commitments.map(&:local_id)
  end

  # All these tests are for clusterable="commitments"
  # but the general principle should hold for the other clusterables.
  # Feel free to add tests for the other clusterables.
  describe "clusterable = commitments" do
    it "Requires a clusterable string" do
      cluster_tap_save [spc1, spc2]
      expect {
        described_class.update_embedded(
          matcher: {ocn: ocn1},
          updater: {local_id: foo}
        )
      }.to raise_error ArgumentError
    end

    it "Requires a matcher" do
      cluster_tap_save [spc1, spc2]
      expect {
        described_class.update_embedded(
          clusterable: "commitments",
          updater: {local_id: foo}
        )
      }.to raise_error Mongo::Error::OperationFailure
    end

    it "Requires an updater" do
      cluster_tap_save [spc1, spc2]
      expect {
        described_class.update_embedded(
          clusterable: "commitments",
          matcher: {ocn: ocn1}
        )
      }.to raise_error Mongo::Error::OperationFailure
    end

    it "Updates matching embedded documents" do
      cluster_tap_save [spc1, spc2, spc3, spc4]
      described_class.update_embedded(
        clusterable: "commitments",
        matcher: {ocn: ocn1},
        updater: {local_id: foo}
      )
      expect(commitment_local_ids(ocn1)).to eq [foo, foo]
      expect(commitment_local_ids(ocn2)).to eq [loc3, loc4]
    end

    it "Gets more specific with additional matching criteria" do
      cluster_tap_save [spc1, spc2, spc3, spc4]
      described_class.update_embedded(
        clusterable: "commitments",
        matcher: {ocn: ocn1, local_id: loc1},
        updater: {local_id: foo}
      )
      expect(commitment_local_ids(ocn1)).to eq [foo, loc2]
      expect(commitment_local_ids(ocn2)).to eq [loc3, loc4]
    end

    it "Allows updating multiple fields on the same embedded document" do
      cluster_tap_save [spc1, spc2]
      described_class.update_embedded(
        clusterable: "commitments",
        matcher: {ocn: ocn1, local_id: loc1},
        updater: {local_id: foo, local_item_id: bar}
      )
      expect(Cluster.first.commitments.first.local_id).to eq foo
      expect(Cluster.first.commitments.first.local_item_id).to eq bar
      expect(Cluster.first.commitments.last.local_id).to eq loc2
      expect(Cluster.first.commitments.last.local_item_id).to eq nil
    end

    it "Allows updating multiple fields on multiple embedded document" do
      cluster_tap_save [spc1, spc2]
      described_class.update_embedded(
        clusterable: "commitments",
        matcher: {ocn: ocn1},
        updater: {local_id: foo, local_item_id: bar}
      )
      expect(Cluster.first.commitments.first.local_id).to eq foo
      expect(Cluster.first.commitments.first.local_item_id).to eq bar
      expect(Cluster.first.commitments.last.local_id).to eq foo
      expect(Cluster.first.commitments.last.local_item_id).to eq bar
    end

    it "can match on undefined fields being null" do
      cluster_tap_save [spc1, spc2]
      described_class.update_embedded(
        clusterable: "commitments",
        matcher: {field_missing: nil},
        updater: {local_id: foo, local_item_id: bar}
      )
      expect(Cluster.first.commitments.first.local_id).to eq foo
      expect(Cluster.first.commitments.first.local_item_id).to eq bar
      expect(Cluster.first.commitments.last.local_id).to eq foo
      expect(Cluster.first.commitments.last.local_item_id).to eq bar
    end

    it "can set a field that does not exist" do
      cluster_tap_save [spc1, spc2]
      expect(Cluster.first.commitments.first.local_item_id).to eq nil
      described_class.update_embedded(
        clusterable: "commitments",
        matcher: {ocn: ocn1},
        updater: {local_item_id: bar}
      )
      expect(Cluster.first.commitments.first.local_item_id).to eq bar
      # We could even set:
      #   updater: {"qux": "baz"}
      # ... but there is no Clusterable::Commitment field for qux
    end
  end
end
