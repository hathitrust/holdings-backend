require "clusterable/holding"
require "solr_record"

# A chunk of solr records for which we can fetch holdings in a batch
class SolrBatch
  attr_reader :records

  # create SolrRecords and clusters in memory for a chunk of lines
  def initialize(lines)
    @records = lines.map { |l| SolrRecord.from_json(l) }
    fetch_holdings
  end

  private

  def fetch_holdings
    ocn_map = Hash.new { |h,k| h[k] = [] }
    records.each do |record|
      record.cluster.ocns.each do |ocn|
        ocn_map[ocn] << record.cluster
      end
    end

    Clusterable::Holding.with_ocns(ocn_map.keys).each do |holding|
      ocn_map[holding.ocn].each do |cluster|
        cluster.add_holding(holding)
      end
    end
    
  end
end
