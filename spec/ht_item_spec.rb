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
  let(:c) { Cluster.new(ocns: htitem_hash[:ocns]) }

  before(:each) do
    described_class.create_indexes
    described_class.collection.find.delete_many
    Cluster.collection.find.delete_many
  end

  it "can be created" do
    expect(described_class.new(htitem_hash)).to be_a(described_class)
  end

  it "prevents duplicates from being created" do
    c.save
    c.ht_items.create(htitem_hash)
    cloned = htitem_hash.clone
    expect { c.ht_items.create(cloned) }.to \
      raise_error(Mongo::Error::OperationFailure, /Duplicate HT Item/)
  end

  describe "#add" do
    let(:htitem2) do
      { ocns:       [rand(1_000_000).to_i, htitem_hash[:ocns]].flatten,
        item_id:    item_id_rand,
        ht_bib_key: ht_bib_key_rand,
        rights:     rand(10).to_s,
        bib_fmt:    rand(10).to_s }
    end
    let(:c2) { Cluster.new(ocns: [htitem2[:ocns].first]) }

    it "creates a cluster if it doesn't exist" do
      expect(Cluster.count).to eq(0)
      described_class.add(htitem2)
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ht_items.first.item_id).to eq(htitem2[:item_id])
    end

    it "merges 2 clusters based on ocns" do
      c.save
      c2.save
      expect(Cluster.count).to eq(2)
      described_class.add(htitem2)
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ht_items.first.item_id).to eq(htitem2[:item_id])
    end

    it "won't add a duplicate entry" do
      c.save
      c2.save
      h3 = htitem2.clone
      h3[:rights] = "pd"
      described_class.add(htitem2)
      expect { described_class.add(h3) }.to \
        raise_error(Mongo::Error::OperationFailure, /Duplicate HT Item/)
    end
  end

  describe "#hathifile_to_record" do
    let(:line) do
      File.open(File.dirname(__FILE__) + "/data/hathifile_line.tsv").read
    end

    it "extracts the fields we want" do
      rec = described_class.hathifile_to_record(line)
      expect(rec).to eq(item_id: "mdp.39015006324134",
        ocns: [1728],
        ht_bib_key: 40,
        rights: "ic",
        bib_fmt: "BK")
    end

    it "creates a record suitable for HTItem creation" do
      rec = described_class.hathifile_to_record(line)
      expect(described_class.new(rec).item_id).to eq("mdp.39015006324134")
    end
  end
end
