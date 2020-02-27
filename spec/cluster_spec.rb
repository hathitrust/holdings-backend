# frozen_string_literal: true

require "cluster"
Mongoid.load!("mongoid.yml", :test)
RSpec.describe Cluster do
  let(:ocn1) { OCLCNumber.new(5) }
  let(:ocn2) { OCLCNumber.new(7) }
  let(:occ1) { OCLCCluster.new([5]) }
  let(:occ2) { OCLCCluster.new([7]) }
  let(:occ3) { OCLCCluster.new([5, 7]) }

  describe "#initialize" do
    it "creates a new cluster" do
      expect(described_class.new(ocns: occ1).class).to eq(described_class)
    end

    it "has an ocns field that is OCLCCluster" do
      expect(described_class.new(ocns: occ1).ocns.class).to eq(OCLCCluster)
    end

    it "has an ocns field with members that are OCLCNumbers" do
      expect(described_class.new(ocns: occ1).ocns.first.class).to eq(OCLCNumber)
    end
  end

  describe "#merge" do
    before(:each) do
      described_class.each(&:delete)
      @cluster1 = described_class.new(ocns: occ1)
      @cluster1.save
      @cluster2 = described_class.new(ocns: occ2)
      @cluster2.save
    end

    after(:all) do
      described_class.each(&:delete)
    end

    it "still a cluster" do
      expect(@cluster1.merge(@cluster2).class).to eq(described_class)
    end

    it "combines ocns sets" do
      expect(@cluster1.merge(@cluster2).ocns).to eq(occ3)
    end

    it "combines holdings" do
      @cluster1.holdings.create(organization: "loc")
      @cluster1.holdings.create(organization: "miu")
      @cluster2.holdings.create(organization: "miu")
      expect(@cluster1.merge(@cluster2).holdings.count).to eq(3)
    end

    it "combines ht_items" do
      @cluster1.ht_items.create(item_id: "miu5")
      @cluster2.ht_items.create(item_id: "uc6")
      expect(@cluster1.merge(@cluster2).ht_items.count).to eq(2)
    end

    it "does not dedupe holdings" do
      @cluster1.holdings.create(organization: "loc")
      @cluster1.holdings.create(organization: "miu")
      @cluster2.holdings.create(organization: "miu")
      expect(@cluster1.merge(@cluster2).holdings.count).to eq(3)
    end

    it "combines commitments" do
      @cluster1.commitments.create(organization: "nypl")
      @cluster2.commitments.create(organization: "nypl")
      @cluster2.commitments.create(organization: "miu")
      expect(@cluster1.merge(@cluster2).commitments.count).to eq(2)
    end
  end

  describe "#save" do
    before(:each) do
      described_class.each(&:delete)
      @cluster1 = described_class.new(ocns: occ3)
      @cluster2 = described_class.new(ocns: occ2)
    end

    after(:each) do
      described_class.each(&:delete)
    end

    it "saves to the database" do
      @cluster1.save
      expect(described_class.count).to eq(1)
      expect(described_class.where(ocns: ocn1).count).to eq(1)
    end

    it "merges conflicting clusters to maintain validity" do
      @cluster1.save
      @cluster2.save
      expect(described_class.count).to eq(1)
      expect(@cluster2.ocns).to eq(occ3)
    end
  end
end
