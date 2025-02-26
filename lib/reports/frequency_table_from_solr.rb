require "frequency_table"
require "clusterable/ht_item"
require "services"
require "milemarker"

# Generates a frequency table given an input file containing
# tabular data from hf:
#    htid bib_num rights_code access bib_fmt description collection_code oclc

module Reports
  class FrequencyTableFromSolr
    def initialize(solr_records, output_file, batch_size: 5000)
      @solr_records = solr_records
      @output_file = output_file
      @batch_size = batch_size
    end

    def run
      freqtable = FrequencyTable.new
      log = Services.logger
      marker = Milemarker.new(batch_size: batch_size)

      # Services.holdings_db.loggers << Logger.new($stdout)
      log.info("starting freq table generation from #{solr_records}")

      File.open(solr_records).each_line do |line|
        solr_record = JSON.parse(line)
        solr_htitems = JSON.parse(solr_record["ht_json"])
        cluster_ocns = solr_record["oclc_search"]

        cluster = if cluster_ocns
          Cluster.new(ocns: cluster_ocns)
        else
          OCNLessCluster.new(bib_key: solr_record["id"])
        end

        cluster.ht_items = solr_htitems.map do |solr_htitem|
          Clusterable::HtItem.new(
            item_id: solr_htitem["htid"],
            ht_bib_key: solr_record["id"],
            # See https://github.com/hathitrust/hathitrust_catalog_indexer/issues/81 for why this is an array..
            rights: solr_htitem["rights"][0],
            bib_fmt: map_bib_fmt(solr_record["format"]),
            enum_chron: solr_htitem["enumcron"],
            collection_code: solr_htitem["collection_code"].upcase,
            ocns: solr_record["oclc"] || [],
            cluster: cluster
          )
        end

        cluster.ht_items.select(&:ic?).each do |htitem|
          freqtable.add_ht_item(htitem)
          marker.incr
          marker.on_batch { |m| log.info m.batch_line }
        end
      end
      log.info marker.final_line
      log.info("done w freq table, writing to #{output_file}")

      File.open(output_file, "w") do |fh|
        fh.puts(freqtable.to_json)
      end
    end

    private

    # TODO compare what catalog indexing does vs. hathifiles
    def map_bib_fmt(bib_fmt)
      return "SE" if bib_fmt.include?("Serial")
      return "BK" if bib_fmt.include?("Book")
      # unknown / should be treated as 'book' for most purposes
      "XX"
    end

    attr_reader :solr_records, :output_file, :batch_size
  end
end
