# frozen_string_literal: true

require "spec_helper"
require "ht_item"
require "cluster"

RSpec.describe HtItem do
  let(:ocn_rand) { rand(1_000_000).to_i }
  let(:item_id_rand) { rand(1_000_000).to_s }
  let(:ht_bib_key_rand) { rand(1_000_000).to_i }
  let(:htitem) { build(:ht_item) }
  let(:htitem_hash) { htitem.to_hash }
  let(:c) { create(:cluster, ocns: htitem_hash[:ocns]) }

  before(:each) do
    described_class.collection.find.delete_many
    Cluster.collection.find.delete_many
  end

  it "can be created" do
    expect(described_class.new(htitem_hash)).to be_a(described_class)
  end

  it "has no parent when built on its own" do
    expect(build(:ht_item)._parent).to be_nil
  end

  it "has a parent when created via a cluster" do
    c.ht_items.create(htitem_hash)
    expect(c.ht_items.first._parent).to be(c)
  end

  it "prevents duplicates from being created" do
    c.ht_items.create(htitem_hash)
    cloned = htitem_hash.clone
    c.ht_items.create(cloned)
    expect { c.save! }.to \
      raise_error(Mongoid::Errors::Validations, /Validation of Cluster failed./)
  end

  it "provides its parent cluster with its ocns" do
    ht_multi_ocns = htitem_hash.clone
    ht_multi_ocns[:ocns] << rand(1_000_000).to_i
    c.ht_items.create(ht_multi_ocns)
    expect(c.ocns.count).to eq(2)
  end

  it "can have an empty ocns field" do
    expect(build(:ht_item, ocns: []).valid?).to be true
  end

  it "normalizes enum_chron" do
    htitem = build(:ht_item, enum_chron: "v.1 Jul 1999")
    expect(htitem.enum_chron).to eq("v.1 Jul 1999")
    expect(htitem.n_enum).to eq("1")
    expect(htitem.n_chron).to eq("Jul 1999")
  end

  it "does nothing if given an empty enum_chron" do
    htitem = build(:ht_item, enum_chron: "")
    expect(htitem.enum_chron).to eq("")
    expect(htitem.n_enum).to be nil
    expect(htitem.n_chron).to be nil
  end

  it "has an access of deny or allow" do
    expect(build(:ht_item).access).to be_in(["allow", "deny"])
  end


  describe "#billing_entity" do
    it "is automatically set when collection_code is set" do
      expect(build(:ht_item, collection_code: "KEIO").billing_entity).to eq("hathitrust")
    end
  end

  describe "#to_hash" do
    it "contains content_provider_code" do
      expect(htitem_hash[:content_provider_code]).not_to be nil
    end

    it "does not contain _id" do
      expect(htitem_hash.key?(:_id)).to be false
    end
  end
end
