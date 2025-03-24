# frozen_string_literal: true

require "spec_helper"
require "clusterable/ht_item"
require "cluster"

RSpec.describe Clusterable::HtItem do
  include_context "with tables for holdings"

  let(:ocn_rand) { rand(1_000_000).to_i }
  let(:item_id_rand) { rand(1_000_000).to_s }
  let(:ht_bib_key_rand) { rand(1_000_000).to_i }
  let(:htitem) { build(:ht_item) }
  let(:htitem_hash) { htitem.to_hash }
  let(:c) { Cluster.new(ocns: htitem_hash[:ocns]) }

  it "can be created" do
    expect(described_class.new(htitem_hash)).to be_a(described_class)
  end

  it "can retrieve from the database" do
    insert_htitem(htitem)

    expect(described_class.find(item_id: htitem.item_id).to_hash).to eq(htitem_hash)
  end

  it "does something if htitem isn't found" do
    expect { described_class.find(item_id: "test.nonexistent") }.to raise_exception(Sequel::NoMatchingRow)
  end

  describe ".ic_volumes" do
    it "counts ic items" do
      %w[ic op und].each do |code|
        insert_htitem build(:ht_item, access: "deny", rights: code)
      end
      expect(described_class.ic_volumes.count).to eq(3)
    end

    it "ignores pd items" do
      %w[pd pdus cc-zero].each do |code|
        insert_htitem build(:ht_item, access: "allow", rights: code)
      end
      expect(described_class.ic_volumes.count).to eq(0)
    end

    it "ignores icus items" do
      insert_htitem build(:ht_item, access: "deny", rights: "icus")
      expect(described_class.ic_volumes.count).to eq(0)
    end
  end

  describe ".pd_count" do
    it "counts pd items" do
      %w[pd pdus cc-zero].each do |code|
        insert_htitem build(:ht_item, access: "allow", rights: code)
      end
      expect(described_class.pd_count).to eq(3)
    end

    it "counts icus items" do
      insert_htitem build(:ht_item, access: "deny", rights: "icus")
      expect(described_class.pd_count).to eq(1)
    end

    it "ignores ic items" do
      %w[ic op und].each do |code|
        insert_htitem build(:ht_item, access: "deny", rights: code)
      end
      expect(described_class.pd_count).to eq(0)
    end
  end

  describe ".count" do
    it "counts all volumes" do
      %w[pd pdus cc-zero].each do |code|
        insert_htitem build(:ht_item, access: "allow", rights: code)
      end
      %w[ic op und icus].each do |code|
        insert_htitem build(:ht_item, access: "deny", rights: code)
      end
      expect(described_class.count).to eq(7)
    end
  end

  it "normalizes enum_chron" do
    htitem = build(:ht_item, enum_chron: "v.1 Jul 1999")
    expect(htitem.enum_chron).to eq("v.1 Jul 1999")
    expect(htitem.n_enum).to eq("1")
    expect(htitem.n_chron).to eq("Jul 1999")
  end

  it "gives empty string if given an empty enum_chron" do
    htitem = build(:ht_item, enum_chron: "")
    expect(htitem.enum_chron).to eq("")
    expect(htitem.n_enum).to eq("")
    expect(htitem.n_chron).to eq("")
  end

  it "has an access of deny or allow" do
    expect(build(:ht_item).access).to eq("allow").or eq("deny")
  end

  it "always returns an integer for ht_bib_key" do
    expect(described_class.new(ht_bib_key: "123456").ht_bib_key).to eq(123456)
  end

  it "ocns is an array of integers" do
    expect(described_class.new(ocns: "1,2,3").ocns).to contain_exactly(1, 2, 3)
  end

  describe "#billing_entity" do
    it "is automatically set when collection_code is set" do
      expect(build(:ht_item, collection_code: "KEIO").billing_entity).to eq("hathitrust")
    end
  end

  describe "#cluster" do
    it "returns a cluster with all its ocns" do
      h = build(:ht_item, ocns: [1, 2])

      expect(h.cluster.ocns).to contain_exactly(1, 2)
    end

    it "with an item without ocns, returns a cluster with no ocns" do
      h = build(:ht_item, ocns: [])

      expect(h.cluster.ocns).to be_empty
    end

    it "can be provided to the constructor" do
      c = double(:cluster)
      h = described_class.new({cluster: c})
      expect(h.cluster).to eq(c)
    end
  end

  describe "#to_hash" do
    it "contains billing_entity" do
      expect(htitem_hash[:billing_entity]).not_to be nil
    end
  end

  describe "#batch_with?" do
    let(:single_ocn1) { build(:ht_item, ocns: [123]) }
    let(:single_ocn2) { build(:ht_item, ocns: [123]) }
    let(:single_ocn3) { build(:ht_item, ocns: [456]) }
    let(:multiple_ocn1) { build(:ht_item, ocns: [123, 456]) }
    let(:multiple_ocn2) { build(:ht_item, ocns: [123, 456]) }
    let(:multiple_ocn3) { build(:ht_item, ocns: [789, 999]) }
    let(:no_ocn1) { build(:ht_item, ocns: [], ht_bib_key: 123) }
    let(:no_ocn2) { build(:ht_item, ocns: [], ht_bib_key: 123) }
    let(:no_ocn3) { build(:ht_item, ocns: [], ht_bib_key: 456) }

    it "batches HTItems with the same single OCN" do
      expect(single_ocn1.batch_with?(single_ocn2)).to be true
    end

    it "batches HTItems with the same multiple OCNs" do
      expect(multiple_ocn1.batch_with?(multiple_ocn2)).to be true
    end

    it "does not batch HTItems with a different single OCN" do
      expect(single_ocn1.batch_with?(single_ocn3)).to be false
    end

    it "does not batch HTItems with a different multiple OCNs" do
      expect(multiple_ocn1.batch_with?(multiple_ocn3)).to be false
    end

    it "does not batch HTItems with different numbers of OCNs" do
      expect(single_ocn1.batch_with?(multiple_ocn1)).to be false
    end

    it "does not batch two HTItems with no OCN but the same bib key" do
      expect(no_ocn1.batch_with?(no_ocn2)).to be false
    end

    it "does not batch two HTItems with no OCN and different bib keys" do
      expect(no_ocn1.batch_with?(no_ocn3)).to be false
    end
  end

  describe "Factory (spec/factories/ht_item.rb)" do
    it "can specify billing_entity" do
      ht_item = build(:ht_item, billing_entity: "umich")
      expect(ht_item.billing_entity).to eq "umich"
    end
    it "can specify collection_code" do
      ht_item = build(:ht_item, collection_code: "MIU")
      expect(ht_item.collection_code).to eq "MIU"
    end
    it "makes sure collection_code and billing_entity belong to the same org" do
      ht_item_with_billing_entity = build(:ht_item, billing_entity: "umich")
      expect(ht_item_with_billing_entity.collection_code).to eq "MIU"

      # Clusterable::HtItem.collection_code= takes care of this for us,
      # by setting the proper billing_entity given a collection_code
      ht_item_with_collection_code = build(:ht_item, collection_code: "MIU")
      expect(ht_item_with_collection_code.billing_entity).to eq "umich"
    end
    it "bases collection_code on billing_entity in case they don't match" do
      ht_item_with_mismatch = build(:ht_item, billing_entity: "umich", collection_code: "PU")
      expect(ht_item_with_mismatch.collection_code).to eq "MIU"
    end
    it "makes billing_entity and collection_code match if neither are specified" do
      ht_item_with_neither = build(:ht_item)
      expect([["umich", "MIU"], ["upenn", "PU"]]).to include [ht_item_with_neither.billing_entity, ht_item_with_neither.collection_code]
    end
  end
end
