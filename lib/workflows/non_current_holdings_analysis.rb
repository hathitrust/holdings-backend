require "workflows/solr"
require "overlap/item_non_current_holdings"

module Workflows
  module NonCurrentHoldingsAnalysis
    class DataSource < Workflows::Solr::DataSource
      def dump_records(output_filename)
        with_milemarked_output(output_filename) do |output_record|
          cursorstream do |s|
            s.filters = ["deleted:false"]
          end.each do |record|
            output_record.call(record)
          end
        end
      end
    end

    class Analyzer < Workflows::Solr::Analyzer
      attr_reader :solr_records, :output_file

      def initialize(solr_records,
        output: solr_records + ".holdings_analysis.ndj")
        @solr_records = solr_records
        @output_file = output
      end

      def run
        log = Services.logger

        # Services.holdings_db.loggers << Logger.new($stdout)
        log.info("starting report generation from #{solr_records}; writing to #{output_file}")

        File.open(output_file, "w") do |fh|
          records_from_file(solr_records).each do |record|
            record.ht_items.each do |ht_item|
              fh.puts(report_for(ht_item).to_json)
            end
          end
        end

        log.info("done w analysis; written to #{output_file}")
      end

      def report_for(ht_item)
        Overlap::ItemNonCurrentHoldings.new(ht_item).to_h
      end
    end

    # Merges output files from Analyzer together and outputs result
    class Writer
      def initialize(working_directory:)
        @working_directory = working_directory
        @report_path = Settings.overlap_reports_path
        Dir.mkdir(@report_path) unless File.exist?(@report_path)

        default_values = {
          lost_missing: 0,
          brittle: 0,
          withdrawn: 0,
          multiple: 0
        }

        @counts = Hash.new do |h, k|
          h[k] = {
            pd: default_values.dup,
            ic: default_values.dup
          }
        end
      end

      def run
        compile_counts
        output_counts
      end

      def header
        [
          "organization",
          "pd: withdrawn",
          "pd: lost/missing",
          "pd: brittle",
          "pd: multiple",
          "ic: withdrawn",
          "ic: lost/missing",
          "ic: brittle",
          "ic: multiple"
        ].join("\t")
      end

      def report_filename
        return @report_filename if @report_filename

        @report_filename = "non_current_holdings_analysis_#{Date.today}.tsv"
      end

      private

      attr_reader :report_path, :working_directory

      def compile_counts
        Dir.glob(File.join(working_directory, "*.ndj")).each do |ndj|
          File.open(ndj).each_line do |line|
            item_analysis = Overlap::ItemNonCurrentHoldings.from_json(line)

            rights = item_analysis.ht_item.ic? ? :ic : :pd

            item_analysis.non_current_holdings.each do |organization, status|
              @counts[organization][rights][status] += 1
            end
          end
        end
      end

      def output_counts
        File.open(report_full_path, "w") do |report|
          report.puts(header)

          @counts.each do |org, org_counts|
            report.puts([
              org,
              org_counts[:pd][:withdrawn],
              org_counts[:pd][:lost_missing],
              org_counts[:pd][:brittle],
              org_counts[:pd][:multiple],
              org_counts[:ic][:withdrawn],
              org_counts[:ic][:lost_missing],
              org_counts[:ic][:brittle],
              org_counts[:ic][:multiple]
            ].join("\t"))
          end
        end
      end

      def report_full_path
        File.join(report_path, report_filename)
      end
    end
  end
end
