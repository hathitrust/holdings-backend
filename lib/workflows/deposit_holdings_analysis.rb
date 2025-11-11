require "workflows/solr"
require "clusterable/ht_item"
require "frequency_table"

module Workflows
  module DepositHoldingsAnalysis
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
                     output: solr_records + ".holdings_analysis.tsv")
        @solr_records = solr_records
        @output_file = output
      end

      def run
        log = Services.logger

        # Services.holdings_db.loggers << Logger.new($stdout)
        log.info("starting report generation from #{solr_records}")

        File.open(output_file, "w") do |fh|
          records_from_file(solr_records).each do |record|
            record.ht_items.select(&:ic?).each do |htitem|
              status = analyze(htitem)

              fh.puts("\t".join(htitem.item_id, htitem.billing_entity, status))
            end
          end
        end

        log.info("done w analysis, writing to #{output_file}")
      end

      def analyze(ht_item)
        overlap = Overlap::ClusterOverlap.overlap_record(ht_item.billing_entity, ht_item)

        return :not_held if overlap.deposited_only?

        # duplicated from lib/api/holdings_api.rb - TODO move to Overlap
        currently_held_count = overlap.copy_count - (overlap.lm_count + overlap.wd_count)

        return :held if currently_held_count.positive?
        return :lost_missing if overlap.lm_count.positive?
        return :withdrawn if overlap.wd_count.positive?

        return :unknown
      end
    end
  end
end
