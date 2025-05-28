# frozen_string_literal: true

require "spec_helper"
require "data_sources/ht_collections"
require "timecop"

RSpec.describe DataSources::HTCollections do
  let(:ht_collections) { described_class.new }

  describe "#collections" do
    it "returns all collections as a hash" do
      expect(ht_collections.collections).to be_a Hash
      expect(ht_collections.collections.keys).to include "MIU"
    end
  end

  describe "#[]" do
    it "can fetch a collection" do
      expect(ht_collections["MIU"].billing_entity).to eq("umich")
    end

    it "raises a KeyError when a collection has no data" do
      expect { ht_collections["nonexistent"] }.to raise_exception(KeyError)
    end
  end

  describe "db connection" do
    include_context "with tables for holdings"
    it "can fetch data from the database" do
      expect(ht_collections["MIU"].billing_entity).to eq("umich")
      expect(ht_collections["KEIO"].billing_entity).to eq("hathitrust")
      expect(ht_collections["UCM"].billing_entity).to eq("ucm")
    end

    it "can fetch the full set of members" do
      expect(ht_collections.collections.size).to be > 88
    end
  end

  describe "cache" do
    it "refreshes ht_collections" do
      Services.ht_db[:ht_collections].where(collection: "foo").delete
      Services.register(:ht_collections) { DataSources::HTCollections.new }

      expected_error = /No collection data for collection:foo/
      expect { Services.ht_collections["foo"] }.to raise_error(KeyError, expected_error)

      # Insert it directly into DB but expect to not see it in the cache.
      Services.ht_db[:ht_collections].insert(
        collection: "foo",
        content_provider_cluster: "foo",
        responsible_entity: "foo",
        original_from_inst_id: "foo",
        billing_entity: "foo"
      )
      # Make sure we actually got it into the db...
      expect(Services.ht_db[:ht_collections].where(collection: "foo").count).to eq 1

      expect { Services.ht_collections["foo"] }.not_to raise_error
      expect(Services.ht_collections["foo"]).to be_a DataSources::HTCollection
    ensure
      Services.ht_db[:ht_collections].where(collection: "foo").delete
    end

    it "refreshes cache after an interval" do
      collections = described_class.new
      collection = "MIU"
      original_responsible_entity = collections[collection].responsible_entity
      new_responsible_entity = "hathitrust"

      Services.ht_db[:ht_collections]
        .where(collection: collection)
        .update(responsible_entity: new_responsible_entity)
      expect(collections[collection].responsible_entity).to eq original_responsible_entity

      Timecop.travel(Time.now + described_class::CACHE_MAX_AGE_SECONDS + 1) do
        expect(collections[collection].responsible_entity).to eq new_responsible_entity
      end
    ensure
      Services.ht_db[:ht_collections]
        .where(collection: collection)
        .update(responsible_entity: original_responsible_entity)
    end
  end
end
