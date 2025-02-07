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
  let(:c) { create(:cluster, ocns: htitem_hash[:ocns]) }

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
  end

  describe ".pd_volumes" do
    it "counts pd items" do
      %w[pd pdus cc-zero].each do |code|
        insert_htitem build(:ht_item, access: "allow", rights: code)
      end
      expect(described_class.pd_volumes.count).to eq(3)
    end

    it "ignores ic items" do
      %w[ic op und].each do |code|
        insert_htitem build(:ht_item, access: "deny", rights: code)
      end
      expect(described_class.pd_volumes.count).to eq(0)
    end
  end

  describe ".all_volumes" do
    it "counts all volumes" do
      %w[pd pdus cc-zero].each do |code|
        insert_htitem build(:ht_item, access: "allow", rights: code)
      end
      %w[ic op und].each do |code|
        insert_htitem build(:ht_item, access: "deny", rights: code)
      end
      expect(described_class.all_volumes.count).to eq(6)
    end
  end

  xit "prevents duplicates from being created" do
    c.ht_items.create(htitem_hash)
    cloned = htitem_hash.clone
    c.ht_items.create(cloned)
    expect { c.save! }.to \
      raise_error(Mongoid::Errors::Validations, /Validation of Cluster failed./)
  end

  xit "provides its parent cluster with its ocns" do
    ht_multi_ocns = htitem_hash.clone
    ht_multi_ocns[:ocns] << rand(1_000_000).to_i
    c.ht_items.create(ht_multi_ocns)
    expect(c.ocns.count).to eq(2)
  end

  xit "can have an empty ocns field" do
    expect(build(:ht_item, ocns: []).valid?).to be true
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

  describe "#billing_entity" do
    it "is automatically set when collection_code is set" do
      expect(build(:ht_item, collection_code: "KEIO").billing_entity).to eq("hathitrust")
    end
  end

  describe "#cluster" do
    it "returns a cluster with all its ocns" do
      create(:cluster, ocns: [1, 2])
      h = build(:ht_item, ocns: [1, 2])

      expect(h.cluster.ocns).to contain_exactly(1, 2)
    end

    it "returns a cluster with some of its ocns (if there is only one)" do
      create(:cluster, ocns: [1])
      h = build(:ht_item, ocns: [1, 2])

      expect(h.cluster.ocns).to contain_exactly(1)
    end

    it "returns nil if there is no cluster" do
      create(:cluster, ocns: [3, 4])
      h = build(:ht_item, ocns: [1, 2])

      expect(h.cluster).to be(nil)
    end

    it "raises an exception if there are multiple clusters with its ocns" do
      create(:cluster, ocns: [1, 2])
      create(:cluster, ocns: [3, 4])
      h = build(:ht_item, ocns: [1, 3])

      expect { h.cluster }.to raise_exception(/multiple clusters/)
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
end
