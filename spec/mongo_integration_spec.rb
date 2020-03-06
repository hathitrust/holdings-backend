# frozen_string_literal: true

require "spec_helper"

require "cluster_mapper"
require "cluster"

RSpec.describe "ClusterMapper with MongoDB", :integration do
  before(:each) do
    Mongoid::Clients.default.collections.each {|c| c.find.delete_many }
  end

  def mapper
    ClusterMapper.new(Cluster)
  end

  def find_resolution(deprecated, resolved)
    OCNResolution.where(deprecated: deprecated, resolved: resolved).first
  end

  def new_resolution(deprecated, resolved)
    OCNResolution.new(deprecated: deprecated, resolved: resolved)
  end

  def expect_mongo_to_have_one_cluster_with(id)
    results = Cluster.collection.find(ocns: id)
    expect(results.count).to eq(1)
    expect(results.first[:ocns]).to include(id)
  end

  it "contains only one persisted cluster per id" do
    tmp_mapper = mapper
    tmp_mapper.add(new_resolution(2, 1))
    tmp_mapper.add(new_resolution(3, 1))
    tmp_mapper.add(new_resolution(4, 5))

    (1..5).each do |id|
      expect_mongo_to_have_one_cluster_with(id)
    end
  end

  describe "#[]" do
    it "retrieves a cluster" do
      tmp_mapper = mapper
      tmp_mapper.add(new_resolution(2, 1))
      tmp_mapper.add(new_resolution(3, 1))

      expect(mapper[1].ocns).to \
        contain_exactly(*(1..3).map {|i| i })
    end
  end

  describe "#add" do
    it "causes clusters to merge when necessary" do
      tmp_mapper = mapper
      tmp_mapper.add(new_resolution(4, 5))
      tmp_mapper.add(new_resolution(6, 7))
      tmp_mapper.add(new_resolution(7, 5))

      expect(mapper[4].ocns).to \
        contain_exactly(*(4..7).map {|i| i })
    end

    it "adds a resolution rule" do
      deprecated = 4
      resolved = 5
      mapper.add(new_resolution(4, 5))

      results = OCNResolution.collection.find(deprecated: deprecated.to_i)
      expect(results.count).to eq(1)
      expect(results.first[:resolved]).to eq(resolved)
    end
  end

  describe "#delete" do
    let(:deprecated1) { 1 }
    let(:deprecated2) { 2 }
    let(:resolved) { 3 }

    before(:each) do
      tmp_mapper = mapper
      tmp_mapper.add(new_resolution(deprecated1, resolved))
      tmp_mapper.add(new_resolution(deprecated2, resolved))
    end

    it "removes the resolution rule" do
      mapper.delete(find_resolution(deprecated1, resolved))

      results = OCNResolution.collection.find(deprecated: deprecated1.to_i)
      expect(results.count).to eq(0)
    end

    it "removes the old deprecated ocn from the cluster" do
      mapper.delete(find_resolution(deprecated1, resolved))

      expect(mapper[resolved].ocns).to contain_exactly(deprecated2, resolved)
      expect(mapper[deprecated1].ocns).to contain_exactly(deprecated1)
    end
  end
end
