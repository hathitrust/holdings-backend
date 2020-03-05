# frozen_string_literal: true

require "cluster_mapper"

RSpec.describe ClusterMapper do
  let(:memory_clusters) do
    Class.new do
      attr_reader :ocns

      def initialize(ocns:)
        @ocns = ocns
      end

      def self.clusters
        @clusters ||= []
      end

      def clusters
        self.class.clusters
      end

      def self.reset
        @clusters = []
      end

      def self.where(ocns:)
        clusters.select {|cluster| cluster.ocns.include?(ocns) }
      end

      def save
        clusters.append(self) unless clusters.include?(self)
      end

      def merge(other)
        @ocns = ocns + other.ocns
        other.delete
      end

      def delete
        clusters.reject! {|cluster| cluster == self }
      end
    end
  end

  let(:mapper) { described_class.new(memory_clusters) }

  before(:each) do
    memory_clusters.reset
  end

  describe "#[]" do
    let(:new_id) { double("new_id") }

    it "returns a new cluster when a cluster with the id doesn't exist" do
      expect(mapper[new_id].ocns).to contain_exactly(new_id)
    end
  end

  describe "#add" do
    let(:ocn1) { double("ocn1") }
    let(:ocn2) { double("ocn2") }
    let(:ocn3) { double("ocn3") }
    let(:ocn4) { double("ocn4") }

    it "can create a new cluster with two ocns" do
      mapper.add(ocn2, ocn1)

      expect(mapper[ocn1].ocns).to contain_exactly(ocn1, ocn2)
    end

    context "with three ocns" do
      before(:each) do
        mapper.add(ocn2, ocn1)
        mapper.add(ocn3, ocn1)
      end

      it "contains a cluster with all ocns" do
        expect(mapper[ocn1].ocns).to contain_exactly(ocn1, ocn2, ocn3)
      end

      it "maps ocn2 and ocn3 to the same cluster" do
        expect(mapper[ocn2]).to eq(mapper[ocn3])
      end
    end

    context "with two clusters that get merged" do
      before(:each) do
        mapper.add(ocn1, ocn2)
        mapper.add(ocn3, ocn4)
        mapper.add(ocn1, ocn3)
      end

      it "can merge existing clusters" do
        expect(mapper[ocn1].ocns).to contain_exactly(ocn1, ocn2, ocn3, ocn4)
      end

      it "maps ocns to the merged cluster" do
        expect(mapper[ocn3]).to eq(mapper[ocn1])
      end

      it "deletes the old cluster after merging" do
        expect(memory_clusters.clusters.length).to eq(1)
      end
    end
  end
end
