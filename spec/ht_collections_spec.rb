# frozen_string_literal: true

require "ht_collections"
require "dotenv"

RSpec.describe HTCollections do
  let(:mock_data) do
    {
      "EXA" => HTCollection.new(collection: "EXA",
                                content_provider_cluster: "excluster",
                                responsible_entity: "example",
                                original_from_inst_id: "example",
                                billing_entity: "example")
    }
  end

  let(:ht_collections) { described_class.new(mock_data) }

  describe "#[]" do
    it "can fetch a collection" do
      expect(ht_collections["EXA"].billing_entity).to eq("example")
    end

    it "raises a KeyError when a collection has no data" do
      expect { ht_collections["nonexistent"] }.to raise_exception(KeyError)
    end
  end

  describe "#collections" do
    it "returns all collections as a hash" do
      expect(ht_collections.collections.keys).to contain_exactly("EXA")
    end
  end

  describe "db connection" do
    # Ensure we have a clean database connection for each test
    around(:each) do |example|
      old_holdings_db = Services.holdings_db
      Services.register(:holdings_db) { HoldingsDB.connection }
      example.run
      Services.register(:holdings_db) { old_holdings_db }
    end

    let(:ht_collections) { described_class.new }

    it "can fetch data from the database" do
      expect(ht_collections["MIU"].billing_entity).to eq("umich")
      expect(ht_collections["KEIO"].billing_entity).to eq("hathitrust")
      expect(ht_collections["UCM"].billing_entity).to eq("ucm")
    end

    it "can fetch the full set of members" do
      expect(ht_collections.collections.size).to be > 88
    end
  end
end
