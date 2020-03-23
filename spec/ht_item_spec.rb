# frozen_string_literal: true

require "ht_item"
require "cluster"
RSpec.describe HtItem do
  let(:ocn_rand) { rand(1_000_000).to_i }
  let(:item_id_rand) { rand(1_000_000).to_s }
  let(:ht_bib_key_rand) { rand(1_000_000).to_i }
  let(:htitem_hash) do
    { ocns:       [ocn_rand],
      item_id:    item_id_rand,
      ht_bib_key: ht_bib_key_rand,
      rights:     rand(10).to_s,
      bib_fmt:    rand(10).to_s }
  end
  let(:c) { create(:cluster, ocns: htitem_hash[:ocns]) }

  before(:each) do
    described_class.create_indexes
    described_class.collection.find.delete_many
    Cluster.collection.find.delete_many
  end

  it "can be created" do
    expect(described_class.new(htitem_hash)).to be_a(described_class)
  end

  it "does not have a parent" do
    expect(described_class.new(htitem_hash)._parent).to be_nil
  end

  it "has a parent" do
    c.ht_items.create(htitem_hash)
    expect(c.ht_items.first._parent).to be(c)
  end

  it "prevents duplicates from being created" do
    c.ht_items.create(htitem_hash)
    cloned = htitem_hash.clone
    expect { c.ht_items.create(cloned) }.to \
      raise_error(Mongo::Error::OperationFailure, /Duplicate HT Item/)
  end

  it "provides its parent cluster with its ocns" do
    ht_multi_ocns = htitem_hash.clone
    ht_multi_ocns[:ocns] << rand(1_000_000).to_i
    c.ht_items.create(ht_multi_ocns)
    expect(c.ocns.count).to eq(2)
  end

  describe "#add" do
    let(:htitem2) do
      { ocns:       [rand(1_000_000).to_i, htitem_hash[:ocns]].flatten,
        item_id:    item_id_rand,
        ht_bib_key: ht_bib_key_rand,
        rights:     rand(10).to_s,
        bib_fmt:    rand(10).to_s }
    end
    let(:c2) { create(:cluster, ocns: [htitem2[:ocns].first]) }

    it "creates a cluster if it doesn't exist" do
      expect(Cluster.count).to eq(0)
      described_class.add(htitem2)
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ht_items.first.item_id).to eq(htitem2[:item_id])
    end

    it "merges 2 clusters based on ocns" do
      c
      c2
      expect(Cluster.count).to eq(2)
      described_class.add(htitem2)
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ht_items.first.item_id).to eq(htitem2[:item_id])
    end

    it "won't add a duplicate entry" do
      c
      c2
      h3 = htitem2.clone
      h3[:rights] = "pd"
      described_class.add(htitem2)
      expect { described_class.add(h3) }.to \
        raise_error(Mongo::Error::OperationFailure, /Duplicate HT Item/)
    end
  end
end
