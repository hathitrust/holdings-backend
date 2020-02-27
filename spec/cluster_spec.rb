# frozen_string_literal: true

require "cluster"
Mongoid.load!("mongoid.yml", :test)
RSpec.describe Cluster do
  describe "#initialize" do
    it "creates a new cluster" do
      expect(described_class.new(ocns: [5]).class).to eq(described_class)
    end
  end

  describe "#merge" do
    before(:each) do
      described_class.each(&:delete)
      @cluster1 = described_class.new(ocns: [5])
      @cluster1.save
      @cluster2 = described_class.new(ocns: [7])
      @cluster2.save
    end

    after(:all) do
      described_class.each(&:delete)
    end

    it "still a cluster" do
      expect(@cluster1.merge(@cluster2).class).to eq(described_class)
    end

    it "combines ocns sets" do
      expect(@cluster1.merge(@cluster2).ocns).to eq([5, 7])
    end

    it "combines holdings" do
      @cluster1.holdings.create(organization: "loc")
      @cluster1.holdings.create(organization: "miu")
      @cluster2.holdings.create(organization: "miu")
      expect(@cluster1.merge(@cluster2).holdings.count).to eq(3)
    end

    it "combines h_t_items" do
      @cluster1.h_t_items.create(item_id: "miu5")
      @cluster2.h_t_items.create(item_id: "uc6")
      expect(@cluster1.merge(@cluster2).h_t_items.count).to eq(2)
    end

    it "does not dedupe holdings" do
      @cluster1.holdings.create(organization: "loc")
      @cluster1.holdings.create(organization: "miu")
      @cluster2.holdings.create(organization: "miu")
      expect(@cluster1.merge(@cluster2).holdings.count).to eq(2)
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
      @cluster1 = described_class.new(ocns: [5, 7])
      @cluster2 = described_class.new(ocns: [7])
    end

    after(:each) do
      described_class.each(&:delete)
    end

    it "saves to the database" do
      @cluster1.save
      expect(described_class.count).to eq(1)
      expect(described_class.where(ocns: 5).count).to eq(1)
    end

    it "merges conflicting clusters to maintain validity" do
      @cluster1.save
      @cluster2.save
      expect(described_class.count).to eq(1)
      expect(@cluster2.ocns).to eq([5, 7])
    end
  end
end
