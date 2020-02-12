# frozen_string_literal: true

require "cluster_mapper"

RSpec.describe ClusterMapper do
  let(:mapper) { described_class.new }

  describe "#[]" do
    let(:new_id) { double("new_id") }

    it "returns a new cluster when a cluster with the id doesn't exist" do
      expect(mapper[new_id].id).to be(new_id)
    end
  end

  describe "#add" do
    let(:id) { double("id") }
    let(:id2) { double("id2") }
    let(:member) { double("member") }
    let(:member2) { double("member2") }

    it "can create a new cluster with a member" do
      mapper.add(id, member)

      expect(mapper[id]).to contain_exactly(id, member)
    end

    it "can map to id via member" do
      mapper.add(id, member)

      expect(mapper[member].id).to eq(id)
    end

    context "with two members" do
      before(:each) do
        mapper.add(id, member)
        mapper.add(id, member2)
      end

      it "contains a cluster with both members" do
        expect(mapper[id]).to contain_exactly(id, member, member2)
      end

      it "maps member and member2 to the same cluster" do
        expect(mapper[member].id).to eq(mapper[member2].id)
      end
    end

    context "with two clusters" do
      before(:each) do
        mapper.add(id, member)
        mapper.add(id2, member2)
      end

      it "can merge existing clusters" do
        mapper.add(id, id2)
        expect(mapper[id]).to contain_exactly(id, member, member2, id2)
      end

      it "maps members to the merged cluster" do
        mapper.add(id, id2)
        expect(mapper[member2].id).to eq(id)
      end
    end
  end
end
