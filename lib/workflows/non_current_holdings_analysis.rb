require "workflows/solr"
require "clusterable/ht_item"
require "frequency_table"

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
        # TODO extract class -- serialize, deserialize, stuff for adding to tables
        {
          item_id: ht_item.item_id,
          rights: ht_item.rights,
          non_current_holdings: analyze(ht_item).to_h
        }
      end

      def analyze(ht_item)
        return enum_for(__method__, ht_item) unless block_given?
        # TODO do we want this?
        # return :no_ocn if ht_item.ocns.empty?

        overlaps = Overlap::ClusterOverlap.new(ht_item.cluster).for_item(ht_item).to_a

        overlaps_by_org = overlaps.group_by(&:org)

        overlaps_by_org.each do |org, overlaps|
          condition = analyze_overlap_records(overlaps)
          yield [org, condition] if condition
        end
      end

      private

      def analyze_overlap_records(overlap_records)
        conditions = Set.new

        # not actually checking not held for this - this is for the case of an
        # institution deposited the item but doesn't report holding it
        # return :not_held if overlap_records.map(&:matching_count).all?(&:zero?)
        return if overlap_records.map(&:matching_count).all?(&:zero?)

        total_brt = overlap_records.sum(&:brt_count)
        total_current = overlap_records.sum(&:current_holding_count)

        # There are current holdings, but they're all brittle
        conditions.add(:brittle) if total_brt.positive? && total_brt == total_current

        # If no current holdings, or they're all brittle
        if total_current.zero? || conditions.include?(:brittle)
          conditions.add(:lost_missing) if overlap_records.sum(&:lm_count).positive?
          conditions.add(:withdrawn) if overlap_records.sum(&:wd_count).positive?
        end

        single_condition(conditions)
      end

      def single_condition(conditions)
        case conditions.size
        when 0
          nil
        when 1
          conditions.first
        else
          :multiple
        end
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

      def ic_or_pd(rights)
        if Clusterable::HtItem::IC_RIGHTS_CODES.include?(rights)
          :ic
        #        elsif org is us and rights are icus then ic?
        #        elsif org is non-us and rights are pdus then ic?
        else
          :pd
        end
      end

      def run
        # TODO extract method
        Dir.glob(File.join(working_directory, "*.ndj")).each do |ndj|
          File.open(ndj).each_line do |line|
            item_analysis = JSON.parse(line)

            rights = ic_or_pd(item_analysis["rights"])

            item_analysis["non_current_holdings"].each do |organization, status|
              @counts[organization][rights][status.to_sym] += 1
            end
          end
        end

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

      def header
        [
          "organization",
          "pd: withdrawn",
          "pd: lost/missing",
          "pd: brittle",
          "pd: multiple",
          "ic: withdrawn",
          "ic: lost/missing",
          "ic: brittle:",
          "ic: multiple"
        ].join("\t")
      end

      def report_filename
        return @report_filename if @report_filename

        @report_filename = "non_current_holdings_analysis_#{Date.today}.tsv"
      end

      private

      attr_reader :report_path, :working_directory

      def report_full_path
        File.join(report_path, report_filename)
      end

      def gzip_report
      end
    end
  end
end
