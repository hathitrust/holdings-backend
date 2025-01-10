require "hathifiles_database"
require "services"

RSpec.shared_context "with hathifiles table" do
  before(:all) do
    hf_db = HathifilesDatabase.new(Services.holdings_db.uri)
    hf_db.recreate_tables!
  end

  before(:each) do
    Services.hathifiles_table.truncate
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
