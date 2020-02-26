# frozen_string_literal: true
require 'pp'
require "cluster"
Mongoid.load!("mongoid.yml", :test)
RSpec.describe Cluster do
  let(:id1) { double("id1") }
  let(:id2) { double("id2") }
  let(:id3) { double("id3") }
#  let(:members) { [id1, id2, id3] }
=begin
  context "with a cluster with only one member" do
    let(:cluster) { described_class.new(id1) }

    it "can be created" do
      expect(cluster).not_to be(nil)
    end

    it "includes that member" do
      expect(cluster.include?(id1)).to be(true)
    end
  end
=end
=begin
  context "with a cluster with multiple members" do
    let(:cluster) { described_class.new(id1, id2) }

    it "can be created" do
      expect(cluster).not_to be(nil)
    end

    it "can tell whether a member is included in the cluster" do
      expect(cluster.include?(id1)).to be(true)
    end
  end
=end
  describe "#initialize" do
    it "creates a new cluster" do
      expect(Cluster.new(ocns:[5]).class).to eq(Cluster)
    end

    it 'takes a holdings' do
      holding = Holding.new({organization:"loc"})
      expect(holding.class).to eq(Holding)
      cluster = Cluster.new(ocns:[5],
                            holdings: [holding])
      expect(cluster.class).to eq(Cluster)
      expect(cluster.holdings).to eq([holding])
    end
  end

  describe "#+" do
    let(:cluster1) { Cluster.new(ocns:[5]) }
    let(:cluster2) { Cluster.new(ocns:[7]) }
   
    it "creates a new cluster" do
      expect((cluster1 + cluster2).class).to eq(described_class)
    end

    it "combines ocns sets" do
      expect((cluster1 + cluster2).ocns).to eq([5,7])
    end

    it "combines ht_items" do
      cluster1.holdings = ['y']
      cluster2.holdings = ['z']
      expect((cluster1 + cluster2).holdings).to eq(['y','z'])
    end

    it "dedupes holdings" do
      cluster1.holdings = ['y', 'z']
      cluster2.holdings = ['z']
      expect((cluster1 + cluster2).holdings).to eq(['y','z'])
    end 
  end

  describe "#embedded_field" do
    let(:cluster1) { Cluster.new() }
    
    it "returns an empty array if field isn't set" do
      expect(cluster1.holdings).to eq([])
    end

    it "returns the embedded documents if field is set" do
      cluster1.holdings = [5]
      expect(cluster1.holdings).to eq([5])
    end
  end

  describe "#save" do
    before(:all) do
      # possible to stub this out?
      @holding = Holding.new(organization: 'loc')
      @cluster1 = Cluster.new(ocns:[5,7],
                              holdings: [@holding])
      PP.pp @cluster1
      @cluster2 = Cluster.new(ocns:[7])
    end 

    it "saves to the database" do
      @cluster1.save
      expect(Cluster.count).to eq(1)
      Cluster.each do |c|
        PP.pp c
      end
    end

    it "merges conflicting clusters to maintain validity" do
      @cluster1.save
      @cluster2.save
      expect(@cluster1.holdings).to eq([@holding])
      expect(@cluster2.holdings).to eq([@holding])
    end

    after(:all) do
      Cluster.each {|c| c.delete}
      puts "cluster count:#{Cluster.count}"
    end
  end

  describe "#merge" do
    let(:cluster1) { described_class.new(ocns:[5],
                                         holdings: [Holding.new]) }
    let(:cluster2) { described_class.new(ocns:[7],
                                         holdings: [Holding.new]) }

    it "includes both ocns after merge" do
      expect(cluster1.merge(cluster2).ocns).to\
        contain_exactly(5, 7)
    end

    it "includes both holdings" do
      expect(cluster1.merge(cluster2).holdings.count).to eq(2)
    end
  end


=begin
  describe "#from_hash" do
    let(:hash) { { members: [id1, id2, id3] } }
    let(:cluster_from_hash) { described_class.from_hash(hash) }

    it "maps members" do
      expect(cluster_from_hash.members).to contain_exactly(id1, id2, id3)
    end
  end
=end
=begin
  describe "#add" do
    it "returns a cluster with the new id as a member" do
      expect(described_class.new(id1).add(id2)).to include(id2)
    end
  end
=end

=begin
  describe "#to_hash" do
    let(:cluster) { described_class.new(*members) }

    it "converts to hash" do
      expect(cluster.to_hash).to eq(members: members)
    end
  end
=end
end
