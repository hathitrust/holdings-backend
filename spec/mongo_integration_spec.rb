# frozen_string_literal: true

require "spec_helper"

require "cluster_mapper"
require "cluster"

RSpec.describe "ClusterMapper with MongoDB", :integration do
  before(:each) do
    Mongoid::Clients.default.collections.each { |c| c.find.delete_many }
  end

  def mapper
    ClusterMapper.new(Cluster)
  end

  def expect_mongo_to_have_one_cluster_with(id)
    results = Cluster.collection.find(ocns: id)
    expect(results.count).to eq(1)
    expect(results.first[:ocns]).to include(id)
  end

  it "contains only one persisted cluster per id" do
    tmp_mapper = mapper
    tmp_mapper.add(2, 1)
    tmp_mapper.add(3, 1)
    tmp_mapper.add(4, 5)

    (1..5).each do |id|
      expect_mongo_to_have_one_cluster_with(id)
    end
  end

  describe "#[]" do
    it "retrieves a cluster" do
      tmp_mapper = mapper
      tmp_mapper.add(2, 1)
      tmp_mapper.add(3, 1)

      expect(mapper[1].ocns).to \
        contain_exactly(*(1..3).map {|i| i })
    end
  end

  describe "#add" do
    it "causes clusters to merge when necessary" do
      tmp_mapper = mapper
      tmp_mapper.add(4, 5)
      tmp_mapper.add(6, 7)
      tmp_mapper.add(7, 5)

      expect(mapper[4].ocns).to \
        contain_exactly(*(4..7).map {|i| i })
    end
  end
end
