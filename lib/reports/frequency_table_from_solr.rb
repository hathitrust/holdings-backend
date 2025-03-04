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
    attr_reader :solr_records, :output_file, :batch_size

    def initialize(solr_records, output_file, batch_size: 1000)
      @solr_records = solr_records
      @output_file = output_file
      @batch_size = batch_size
    end

    def run
      freqtable = FrequencyTable.new
      log = Services.logger
      milemarker = Milemarker.new(batch_size: batch_size)
      milemarker.logger = Services.logger

      # Services.holdings_db.loggers << Logger.new($stdout)
      log.info("starting freq table generation from #{solr_records}")

      File.open(solr_records).each_line do |line|
        SolrRecord.from_json(line).ht_items.select(&:ic?).each do |htitem|
          freqtable.add_ht_item(htitem)
          milemarker.increment_and_log_batch_line
        end
      end

      milemarker.log_final_line
      log.info("done w freq table, writing to #{output_file}")

      File.open(output_file, "w") do |fh|
        fh.puts(freqtable.to_json)
      end
    end
  end
end
