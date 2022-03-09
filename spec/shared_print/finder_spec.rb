# frozen_string_literal: true

require "spec_helper"
require "shared_print/finder"

RSpec.describe SharedPrint::Finder do
  let(:ocn1) { 1 }
  let(:org1) { "umich" }
  let(:loc1) { "i111" }
  let(:spc1) { build(:commitment, ocn: ocn1, organization: org1, local_id: loc1) }

  let(:ocn2) { 2 }
  let(:org2) { "yale" }
  let(:loc2) { "i222" }
  let(:spc2) { build(:commitment, ocn: ocn2, organization: org2, local_id: loc2) }

  let(:ocn999) { 999 }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  describe "return types" do
    it "#clusters yields Cluster values" do
      cluster_tap_save [spc1]
      expect(described_class.new(ocn: [ocn1]).clusters).to be_a Enumerator
      described_class.new(ocn: [ocn1]).clusters do |cluster|
        expect(cluster).to be_a Cluster
      end
    end
    it "#commitments yields Clusterable::Commitment values" do
      cluster_tap_save [spc1]
      expect(described_class.new(ocn: [ocn1]).commitments).to be_a Enumerator
      described_class.new(ocn: [ocn1]).commitments do |commitment|
        expect(commitment).to be_a Clusterable::Commitment
      end
    end
    it "#clusters.to_a returns an array of Cluster values" do
      cluster_tap_save [spc1]
      res = described_class.new(ocn: [ocn1]).clusters.to_a
      expect(res.map(&:class)).to eq [Cluster]
    end
    it "#commitments.to_a returns an array of Clusterable::Commitment values" do
      cluster_tap_save [spc1]
      res = described_class.new(ocn: [ocn1]).commitments.to_a
      expect(res.map(&:class)).to eq [Clusterable::Commitment]
    end
  end

  describe "search criteria" do
    it "finds nothing if there is nothing to find" do
      res = described_class.new.commitments.to_a
      expect(res.empty?).to be true
    end
    it "finds nothing if the criteria matches nothing" do
      cluster_tap_save [spc1, spc2]
      res = described_class.new(ocn: [ocn999]).commitments.to_a
      expect(res.empty?).to be true
    end
    it "returns all if given no further search criteria" do
      cluster_tap_save [spc1, spc2]
      res = described_class.new.commitments.to_a
      expect(res.size).to eq 2
    end
    it "can search by single OCN" do
      cluster_tap_save [spc1, spc2]
      res = described_class.new(ocn: [ocn1]).commitments.to_a
      expect(res.map(&:ocn)).to eq [ocn1]
    end
    it "can search by multiple OCNs" do
      cluster_tap_save [spc1, spc2]
      res = described_class.new(ocn: [ocn1, ocn2]).commitments.to_a
      expect(res.map(&:ocn)).to eq [ocn1, ocn2]
    end
    it "can search by single org" do
      cluster_tap_save [spc1, spc2]
      res = described_class.new(organization: [org1]).commitments.to_a
      expect(res.map(&:organization)).to eq [org1]
    end
    it "can search by multiple orgs" do
      cluster_tap_save [spc1, spc2]
      res = described_class.new(organization: [org1, org2]).commitments.to_a
      expect(res.map(&:organization)).to eq [org1, org2]
    end
    it "can search by single local_id" do
      cluster_tap_save [spc1, spc2]
      res = described_class.new(local_id: [loc1]).commitments.to_a
      expect(res.map(&:local_id)).to eq [loc1]
    end
    it "can search by multiple local_ids" do
      cluster_tap_save [spc1, spc2]
      res = described_class.new(local_id: [loc1, loc2]).commitments.to_a
      expect(res.map(&:local_id)).to eq [loc1, loc2]
    end
  end

  describe "deprecated records" do
    it "ignores deprecated commitments by default" do
      spc2.deprecate(status: "E")
      cluster_tap_save [spc1, spc2]
      res = described_class.new.commitments.to_a
      expect(res.map(&:ocn)).to eq [ocn1]
    end
    it "can search deprecated commitments if told to" do
      spc2.deprecate(status: "E")
      cluster_tap_save [spc1, spc2]
      res = described_class.new(deprecated: true).commitments.to_a
      expect(res.map(&:ocn)).to eq [ocn2]
    end
    it "can combine deprecated and active commitments" do
      spc2.deprecate(status: "E")
      cluster_tap_save [spc1, spc2]
      res = described_class.new(deprecated: nil).commitments.to_a
      expect(res.map(&:ocn)).to eq [ocn1, ocn2]
      expect(res.map(&:deprecated?)).to eq [false, true]
    end
  end
end