require "hathifiles_database"
require "services"

RSpec.shared_context "with tables for holdings" do
  let(:db_rw) { Services.holdings_rw_db }
  let(:db_ro) { Services.ht_ro_db }

  before(:all) do
    hf_db = HathifilesDatabase.new
    hf_db.recreate_tables!
  end

  around(:each) do |example|
    db_rw.transaction(rollback: :always, auto_savepoint: true) do
      db_ro.transaction(rollback: :always, auto_savepoint: true) do
        example.run
      end
    end
  end

  # e.g. insert_htitem(build(:ht_item))
  def insert_htitem(htitem)
    new_htitem_attrs = {
      htid: htitem.item_id,
      bib_num: htitem.ht_bib_key,
      rights_code: htitem.rights,
      access: htitem.access == "allow",
      bib_fmt: htitem.bib_fmt,
      description: htitem.enum_chron,
      collection_code: htitem.collection_code,
      oclc: htitem.ocns.join(",")
    }

    Services.hathifiles_table.insert(new_htitem_attrs)
    htitem.ocns.each do |ocn|
      Services.hathifiles_ocn_table.insert(htid: htitem.item_id, value: ocn)
    end
  end
end
