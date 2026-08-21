# frozen_string_literal: true

require "services"
require "settings"
require "overlap/cluster_overlap"
require "overlap/report_record"
require "overlap/report_record_matching_members_count"
require "workflows/solr"
require "workflows/overlap_analyzer"
require "workflows/overlap_writer"

module Workflows
  module OverlapReport
    class DataSource < Workflows::Solr::DataSource
      attr_reader :organization

      def initialize(organization:,
        ocns_per_solr_query: Settings.solr_data_source.ocns_per_solr_query,
        # unused, for parity with other workflow components
        report_record_class: nil)
        @organization = organization
        @solr_records_seen = Set.new
        @ocns_per_solr_query = ocns_per_solr_query
      end

      def dump_records(output_filename)
        with_milemarked_output(output_filename) do |output_record|
          Clusterable::Holding.for_organization(organization)
            .each_slice(@ocns_per_solr_query) do |holdings_slice|
              ocns = holdings_slice.map(&:ocn)
              matched_ocns = find_matching_ocns(ocns, output_record)
              output_unmatched_ocns(ocns, matched_ocns, output_record)
            end
        end
      end

      def output_unmatched_ocns(ocns, matched_ocns, output_record)
        # stub result for ocns that didn't match anything in this batch,
        # so we can write overlap records for unmatched holdings
        ocns.to_set.subtract(matched_ocns).each do |unmatched_ocn|
          output_record.call({
            format: "Unknown",
            oclc_search: [unmatched_ocn],
            ht_json: "[]"
          })
        end
      end

      def find_matching_ocns(ocns, output_record)
        Set.new.tap do |matched_ocns|
          # TODO once API is complete for updating member holdings in
          # catalog -- try querying for held records - any faster?
          cursorstream do |s|
            s.filters = ["oclc_search:(#{ocns.join(" ")})"]
          end.each do |record|
            next if @solr_records_seen.include?(record["id"])
            @solr_records_seen.add(record["id"])
            matched_ocns.merge(record["oclc_search"].map(&:to_i))
            output_record.call(record)
          end
        end
      end
    end

    # Analyzes batches of solr records and computes overlap
    class Analyzer < Workflows::OverlapAnalyzer
      def initialize(input, organization:, report_record_class: Overlap::ReportRecord)
        super
        @holdings_scope = {organization: organization}
      end

      def missed_holdings(cluster, holdings_matched)
        relevant_holdings = cluster.holdings.select { |h| h.organization == organization }
        super(cluster, holdings_matched, relevant_holdings: relevant_holdings)
      end
    end

    # Merges output files from Analyzer together and uploads to dropbox
    class Writer < Workflows::OverlapWriter
      def initialize(organization:, working_directory:, report_record_class: Overlap::ReportRecord)
        super(working_directory: working_directory, report_record_class: report_record_class)
        @organization = organization
      end

      protected

      def notification_message
        message = "Overlap report complete for *#{organization}* — #{report_filename(organization)}"
        message += "\n#{dropbox_url(organization)}" if Settings.overlap_reports_remote_path_url

        message
      end

      def report_gz_path(organization = @organization)
        @report_gz_path ||= super
      end

      def finalize_report
        FileUtils.cp(report_gz_path, persistent_report_path)
        rclone_move(report_gz_path, organization)
      end

      def collate_report
        Zlib::GzipWriter.open(report_gz_path) do |gz|
          gz.puts(header)
          Dir.glob(File.join(working_directory, "*.overlap.tsv")).each do |rpt|
            File.open(rpt) do |file|
              while (chunk = file.read(16 * 1024))
                gz.write(chunk)
              end
            end
          end
        end
      end
    end
  end
end
