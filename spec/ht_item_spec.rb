# frozen_string_literal: true

require "spec_helper"
require "ht_item"
require "cluster"

RSpec.describe HtItem do
  let(:ocn_rand) { rand(1_000_000).to_i }
  let(:item_id_rand) { rand(1_000_000).to_s }
  let(:ht_bib_key_rand) { rand(1_000_000).to_i }
  let(:htitem_hash) { build(:ht_item).to_hash }
  let(:c) { create(:cluster, ocns: htitem_hash[:ocns]) }

  before(:each) do
    described_class.collection.find.delete_many
    Cluster.collection.find.delete_many
  end

  it "can be created" do
    expect(described_class.new(htitem_hash)).to be_a(described_class)
  end

  it "does not have a parent" do
    expect(build(:ht_item)._parent).to be_nil
  end

  it "has a parent" do
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
    cloned = htitem_hash
    enumchron_input = "v.1 Jul 1999"
    cloned[:enum_chron] = enumchron_input
    c.ht_items.create(cloned)
    expect(c.ht_items.first.enum_chron).to eq(enumchron_input)
    expect(c.ht_items.first.n_enum).to eq("1")
    expect(c.ht_items.first.n_chron).to eq("Jul 1999")
  end

  it "does nothing if given an empty enum_chron" do
    cloned = htitem_hash
    enumchron_input = ""
    cloned[:enum_chron] = enumchron_input
    c.ht_items.create(cloned)
    expect(c.ht_items.first.enum_chron).to eq(enumchron_input)
    expect(c.ht_items.first.n_enum).to eq(nil)
    expect(c.ht_items.first.n_chron).to eq(nil)
  end
end
