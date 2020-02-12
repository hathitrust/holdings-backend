# frozen_string_literal: true

require "spec_helper"

require "cluster_mapper"
require "mongo_cluster"

RSpec.describe "ClusterMapper with MongoDB", :integration do
  before(:each) do
    Services.cluster_collection.drop
  end

  def mapper
    ClusterMapper.new(MongoCluster)
  end

  def expect_mongo_to_have_one_cluster_with(id)
    results = Services.cluster_collection.find(members: id.to_i)
    expect(results.count).to eq(1)
    expect(results.first[:members]).to include(id)
  end

  it "contains only one persisted cluster per id" do
    tmp_mapper = mapper
    tmp_mapper.add(OCLCNumber.new(1), OCLCNumber.new(2))
    tmp_mapper.add(OCLCNumber.new(1), OCLCNumber.new(3))
    tmp_mapper.add(OCLCNumber.new(4), OCLCNumber.new(5))
    tmp_mapper.add(OCLCNumber.new(6), OCLCNumber.new(7))

    (1..7).each do |id|
      expect_mongo_to_have_one_cluster_with(OCLCNumber.new(id))
    end
  end

  describe "#[]" do
    it "retrieves a cluster" do
      tmp_mapper = mapper
      tmp_mapper.add(OCLCNumber.new(1), OCLCNumber.new(2))
      tmp_mapper.add(OCLCNumber.new(1), OCLCNumber.new(3))

      expect(mapper[OCLCNumber.new(1)]).to \
        contain_exactly(*(1..3).map {|i| OCLCNumber.new(i) })
    end
  end

  describe "#add" do
    it "causes clusters to merge when necessary" do
      tmp_mapper = mapper
      tmp_mapper.add(OCLCNumber.new(4), OCLCNumber.new(5))
      tmp_mapper.add(OCLCNumber.new(6), OCLCNumber.new(7))
      tmp_mapper.add(OCLCNumber.new(7), OCLCNumber.new(5))

      expect(mapper[OCLCNumber.new(4)]).to \
        contain_exactly(*(4..7).map {|i| OCLCNumber.new(i) })
    end
  end
end
