# frozen_string_literal: true

require "cluster_mapper"

RSpec.describe ClusterMapper do
  let(:memory_clusters) do
    Class.new(Cluster) do
      def self.clusters
        @clusters ||= []
      end

      def clusters
        self.class.clusters
      end

      def self.reset
        @clusters = []
      end

      def self.find_by_member(id)
        clusters.find {|cluster| cluster.members.include?(id) }
      end

      def save
        clusters.append(self) unless clusters.include?(self)
      end

      def delete
        clusters.reject! {|cluster| cluster == self }
      end
    end
  end

  let(:mapper) { described_class.new(memory_clusters) }

  before(:each) { memory_clusters.reset }

  describe "#[]" do
    let(:new_id) { double("new_id") }

    it "returns a new cluster when a cluster with the id doesn't exist" do
      expect(mapper[new_id]).to contain_exactly(new_id)
    end
  end

  describe "#add" do
    let(:id1) { double("id1") }
    let(:id2) { double("id2") }
    let(:id3) { double("id3") }
    let(:id4) { double("id4") }

    it "can create a new cluster with two members" do
      mapper.add(id1, id2)

      expect(mapper[id1]).to contain_exactly(id1, id2)
    end

    context "with three members" do
      before(:each) do
        mapper.add(id1, id2)
        mapper.add(id1, id3)
      end

      it "contains a cluster with all members" do
        expect(mapper[id1]).to contain_exactly(id1, id2, id3)
      end

      it "maps id2 and id3 to the same cluster" do
        expect(mapper[id2]).to eq(mapper[id3])
      end
    end

    context "with two clusters that get merged" do
      before(:each) do
        mapper.add(id1, id2)
        mapper.add(id3, id4)
        mapper.add(id1, id3)
      end

      it "can merge existing clusters" do
        expect(mapper[id1]).to contain_exactly(id1, id2, id3, id4)
      end

      it "maps members to the merged cluster" do
        expect(mapper[id3]).to eq(mapper[id1])
      end

      it "deletes the old cluster after merging" do
        expect(memory_clusters.clusters.length).to eq(1)
      end
    end
  end
end
