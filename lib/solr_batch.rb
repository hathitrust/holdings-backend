require "clusterable/holding"
require "solr_record"

# A chunk of solr records for which we can fetch holdings in a batch
class SolrBatch
  attr_reader :records

  # create SolrRecords and clusters in memory from json lines;
  # populates those clusters with holdings fetched from the database.
  #
  # if a scope is given, i.e. { organization: someorg }, limits retrieved 
  # holdings to that scope. Otherwise, retrieves all holdings.
  def initialize(lines, **holdings_scope)
    @records = lines.map { |l| SolrRecord.from_json(l) }
    fetch_holdings(holdings_scope)
  end

  private

  def fetch_holdings(scope)
    ocn_map = Hash.new { |h, k| h[k] = [] }
    records.each do |record|
      cluster = record.cluster
      # ensure we don't later try to automatically load holdings from the database
      cluster.no_db_load!
      cluster.ocns.each do |ocn|
        ocn_map[ocn] << cluster
      end
    end

    Clusterable::Holding.with_ocns(ocn_map.keys, **scope).each do |holding|
      ocn_map[holding.ocn].each do |cluster|
        cluster.add_holding(holding)
      end
    end
  end
end
