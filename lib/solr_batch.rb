require "clusterable/holding"
require "solr_record"

# A chunk of solr records for which we can fetch holdings in a batch
class SolrBatch
  attr_reader :records

  # create SolrRecords and clusters in memory for a chunk of lines
  def initialize(lines, organization: nil)
    @records = lines.map { |l| SolrRecord.from_json(l) }
    fetch_holdings(organization)
  end

  private

  def fetch_holdings(organization)
    ocn_map = Hash.new { |h, k| h[k] = [] }
    records.each do |record|
      cluster = record.cluster
      # FIXME: severely janky
      #
      # prevent from fetching holdings via sql
      # issue is that if there aren't any holdings for this cluster, we'll try
      # to fetch via SQL and if this is an ocnless-cluster (which can happen
      # for the cost report) we can't set an empty holdings
      #
      # maybe we should explicitly add a method to fetch via sql if we want them?
      # or maybe we tell the cluster we're going to manually add holdings?
      cluster.holdings = [] if cluster.respond_to?(:holdings=)
      cluster.ocns.each do |ocn|
        ocn_map[ocn] << cluster
      end
    end

    Clusterable::Holding.with_ocns(ocn_map.keys, organization: organization).each do |holding|
      ocn_map[holding.ocn].each do |cluster|
        cluster.add_holding(holding)
      end
    end
  end
end
