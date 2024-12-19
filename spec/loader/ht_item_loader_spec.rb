# frozen_string_literal: true

require "spec_helper"
require "loader/ht_item_loader"

RSpec.xdescribe Loader::HtItemLoader do
  let(:line) do
    [
      "test.123456", # htid
      "deny", # access
      "ic", # rights
      "000000123", # ht_bib_key
      "", # description
      "TEST", # source
      "000000123", # source_bib_num
      "99999", # oclc_num
      "0123456789", # isbn
      "", # issn
      "12345678", # lccn
      "Test Title", # title
      "Test Publisher, 1970", # imprint
      "bib", # rights_reason_code
      "2020-10-01 00:00:00", # rights_timestamp
      "0", # us_gov_doc_flag
      "1970", # rights_date_used
      "xxu", # pub_place
      "eng", # lang
      "BK", # bib_fmt
      "TEST", # collection_code
      "test", # content_provider_code
      "test", # responsible_entity_code
      "test", # digitization_agent_code
      "open", # access_profile_code
      "Author, A. Test" # author
    ].join("\t")
  end

  describe "#item_from_line" do
    let(:item) { described_class.new.item_from_line(line) }

    it { expect(item).to be_a(Clusterable::HtItem) }
    it { expect(item.ocns).to contain_exactly(99_999) }
    it { expect(item.item_id).to eq "test.123456" }
    it { expect(item.ht_bib_key).to eq 123 }
    it { expect(item.rights).to eq "ic" }
    it { expect(item.access).to eq "deny" }
    it { expect(item.bib_fmt).to eq "BK" }
    it { expect(item.enum_chron).to eq("") }
    it { expect(item.collection_code).to eq("TEST") }
  end

  describe "#load" do
    before(:each) { Cluster.each(&:delete) }

    it "persists a batch of HTItems" do
      item1 = build(:ht_item)
      item2 = build(:ht_item, ocns: item1.ocns)

      described_class.new.load([item1, item2])

      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ht_items.count).to eq(2)
    end
  end
end
