require "solr_record"
require "spec_helper"

RSpec.describe SolrRecord do
  def record_from_fixture(fixture)
    described_class.from_json(File.read(fixture(fixture)))
  end

  context "with a record for a book" do
    let(:record) { record_from_fixture("solr_catalog_record.ndj") }

    it "can deserialize a record from json" do
      expect(record).to be_a SolrRecord
    end

    it "gets cluster" do
      expect(record.cluster.ocns).to contain_exactly(2779601)
    end

    it "adds cluster to htitem" do
      expect(record.ht_items.map(&:cluster)).to all eq(record.cluster)
    end

    it "adds htitems to cluster" do
      expect(record.ht_items).to eq(record.cluster.ht_items)
    end

    describe "deserialized ht item" do
      let(:ht_item) { record.ht_items.first }

      it "has item id" do
        expect(ht_item.item_id).to eq("mdp.39015066356547")
      end

      it "has bib key" do
        expect(ht_item.ht_bib_key).to eq(1)
      end

      it "has rights" do
        expect(ht_item.rights).to eq("ic")
      end

      it "has BK bib_fmt" do
        expect(ht_item.bib_fmt).to eq("BK")
      end

      it "has normalized enumchron" do
        expect(ht_item.n_enum).to eq("1")
      end

      it "has billing entity" do
        expect(ht_item.billing_entity).to eq("umich")
      end

      it "has ocn" do
        expect(ht_item.ocns).to contain_exactly(2779601)
      end
    end
  end

  context "with a serials record" do
    let(:record) { record_from_fixture("solr_serial_record.ndj") }

    it "cluster has all ocns from oclc_search" do
      expect(record.cluster.ocns.length).to eq(4)
    end

    it "ht_items have bib format SE" do
      expect(record.ht_items.map(&:bib_fmt)).to all eq("SE")
    end
  end

  it "gets a cluster for an ocnless item" do
    expect(record_from_fixture("solr_ocnless_record.ndj").cluster).to be_a(OCNLessCluster)
  end
end
