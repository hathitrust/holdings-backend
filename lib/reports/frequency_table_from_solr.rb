require "frequency_table"
require "clusterable/ht_item"
require "services"
require "milemarker"
require "solr_record"

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
        SolrRecord.from_json(line).ht_items.select(&:ic?).each do |htitem|
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

    attr_reader :solr_records, :output_file, :batch_size
  end
end
