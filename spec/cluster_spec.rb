# frozen_string_literal: true

require "pp"
require "cluster"

RSpec.describe Cluster do
  let(:ocn1) { 5 }
  let(:ocn2) { 6 }

  before(:each) do
    described_class.create_indexes
    described_class.collection.find.delete_many
  end

  describe "#initialize" do
    it "creates a new cluster" do
      expect(described_class.new(ocns: [ocn1]).class).to eq(described_class)
    end

    it "has an ocns field that is Array" do
      expect(described_class.new(ocns: [ocn1]).ocns.class).to eq(Array)
    end

    it "has an ocns field with members that are OCLCNumbers" do
      expect(described_class.new(ocns: [ocn1]).ocns.first.class).to eq(Integer)
    end

    xit "validates the ocns field is numeric" do
      expect(described_class.new(ocns: ["a"])).not_to be_valid
    end
  end

  describe "#merge" do
    let(:c1) { described_class.new(ocns: [ocn1]) }
    let(:c2) { described_class.new(ocns: [ocn2]) }

    before(:each) do
      c1.save
      c2.save
    end

    it "still a cluster" do
      expect(c1.merge(c2).class).to eq(described_class)
    end

    it "combines ocns sets" do
      expect(c1.merge(c2).ocns).to eq([ocn1, ocn2])
    end

    it "combines holdings but does not dedupe" do
      c1.holdings.create(organization: "loc")
      c1.holdings.create(organization: "miu")
      c2.holdings.create(organization: "miu")
      expect(c1.merge(c2).holdings.count).to eq(3)
    end

    it "combines ht_items" do
      c1.ht_items.create(item_id: "miu5")
      c2.ht_items.create(item_id: "uc6")
      expect(c1.merge(c2).ht_items.count).to eq(2)
    end

    it "combines and dedupes commitments" do
      c1.commitments.create(organization: "nypl")
      c2.commitments.create(organization: "nypl")
      c2.commitments.create(organization: "miu")
      expect(c1.merge(c2).commitments.count).to eq(2)
    end
  end

  describe "#save" do
    let(:c1) { described_class.new(ocns: [ocn1, ocn2]) }
    let(:c2) { described_class.new(ocns: [ocn2]) }

    it "can't save them both" do
      c1.save
      expect { c2.save }.to \
        raise_error(Mongo::Error::OperationFailure, /duplicate key error/)
    end

    it "saves to the database" do
      c1.save
      expect(described_class.count).to eq(1)
      expect(described_class.where(ocns: ocn1).count).to eq(1)
    end
  end
end
