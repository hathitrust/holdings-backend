require "workflows/solr"
require "clusterable/ht_item"
require "frequency_table"

module Workflows
  module CostReport
    class DataSource < Workflows::Solr::DataSource
      def dump_records(output_filename)
        with_milemarked_output(output_filename) do |output_record|
          cursorstream do |s|
            s.filters = filters
          end.each do |record|
            output_record.call(record)
          end
        end
      end

      def filters
        ic_rights = Clusterable::HtItem::IC_RIGHTS_CODES.join(" ")
        ["ht_rightscode:(#{ic_rights})"]
      end
    end

    class Analyzer < Workflows::Solr::Analyzer
      attr_reader :solr_records, :output_file

      def initialize(solr_records,
        output: solr_records + ".freqtable.json")
        @solr_records = solr_records
        @output_file = output
      end

      def run
        freqtable = FrequencyTable.new
        log = Services.logger

        # Services.holdings_db.loggers << Logger.new($stdout)
        log.info("starting freq table generation from #{solr_records}")

        records_from_file(solr_records).each do |record|
          record.ht_items.select(&:ic?).each do |htitem|
            freqtable.add_ht_item(htitem)
          end
        end

        log.info("done w freq table, writing to #{output_file}")

        File.open(output_file, "w") do |fh|
          fh.puts(freqtable.to_json)
        end
      end
    end
  end
end
