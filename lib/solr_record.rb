class SolrRecord
  attr_reader :record, :ht_items

  def self.from_json(line)
    new(JSON.parse(line))
  end

  def initialize(record)
    @record = record
    @bib_fmt = map_bib_fmt(record["format"])
    parse_ht_items
  end

  def cluster
    @cluster ||= if record["oclc_search"]
      Cluster.new(ocns: record["oclc_search"])
    else
      OCNLessCluster.new(bib_key: record["id"])
    end
  end

  def parse_ht_items
    @ht_items = cluster.ht_items =
      JSON.parse(record["ht_json"]).map do |solr_htitem|
        htitem(solr_htitem)
      end
  end

  private

  attr_reader :bib_fmt

  def htitem(solr_htitem)
    # need this for overlap reports, although arguably it isn't very useful
    # there as it isn't responsive to us vs. non-us
    rights = solr_htitem["rights"][0]
    ic = Clusterable::HtItem::IC_RIGHTS_CODES.include?(rights)
    access = if ic || rights == "icus"
      "deny"
    else
      "allow"
    end

    Clusterable::HtItem.new(
      item_id: solr_htitem["htid"],
      ht_bib_key: record["id"],
      # See https://github.com/hathitrust/hathitrust_catalog_indexer/issues/81 for why this is an array..
      rights: solr_htitem["rights"][0],
      access: access,
      bib_fmt: bib_fmt,
      enum_chron: solr_htitem["enumcron"],
      collection_code: solr_htitem["collection_code"].upcase,
      ocns: record["oclc"] || [],
      cluster: cluster
    )
  end

  def map_bib_fmt(solr_bib_fmt)
    return "SE" if solr_bib_fmt.include?("Serial")
    return "BK" if solr_bib_fmt.include?("Book")
    # unknown / should be treated as 'book' for most purposes
    "XX"
  end
end
