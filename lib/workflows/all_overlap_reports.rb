# frozen_string_literal: true

require "services"
require "overlap/cluster_overlap"
require "overlap/report_record"
require "overlap/report_record_matching_members_count"
require "workflows/map_reduce"
require "workflows/solr"
require "workflows/overlap_analyzer"
require "workflows/overlap_writer"

module Workflows
  module AllOverlapReports
    class DataSource < Workflows::Solr::DataSource
      def dump_records(output_filename)
        @workdir = File.dirname(output_filename)
        @catalog_ocns = File.join(@workdir, "catalog_ocns")

        File.open(@catalog_ocns, "w") do |catalog_ocn_fh|
          with_milemarked_output(output_filename) do |output_record|
            cursorstream { |s| s.filters = ["deleted:false"] }.each do |record|
              output_record.call(record)
              record["oclc_search"]&.each { |ocn| catalog_ocn_fh.puts(ocn) }
            end
          end
        end

        gather_nonmatching_holding_ocns(output_filename)
      end

      private

      def gather_nonmatching_holding_ocns(output_filename)
        all_holding_ocns = File.join(@workdir, "distinct_holdings_ocn.sort")
        nonmatching_ocns = File.join(@workdir, "nonmatching_ocns")
        Services.logger.info("Dumping distinct holdings OCNs and sorting")

        # --quick enables result streaming for the command-line client. trilogy
        # doesn't support result set streaming, so doing this in ruby would use
        # a lot of memory and be very slow. It takes about 20 minutes
        # via this method.

        mariadb_path = File.join(File.dirname(__FILE__), "..", "..", "bin", "mariadb.sh")
        system("#{mariadb_path} --quick -N -B -e 'SELECT DISTINCT ocn FROM holdings' | sort -T #{@workdir} > #{all_holding_ocns}", exception: true)

        Services.logger.info("Sorting OCNs from catalog")
        system("sort -T #{@workdir} #{@catalog_ocns} | uniq > #{@catalog_ocns}.sort", exception: true)
        Services.logger.info("Comparing OCNs from catalog and holdings")
        system("comm -1 -3 #{@catalog_ocns}.sort #{all_holding_ocns} > #{nonmatching_ocns}", exception: true)

        Services.logger.info("Outputting nonmatching OCNs")

        File.open(output_filename, "a") do |output|
          File.open(nonmatching_ocns).each_line do |line|
            output.puts(%({ "format": "Unknown", "oclc_search": [#{line.strip}], "ht_json": "[]" }))
          end
        end

        Services.logger.info("Completed gathering nonmatching holding OCNs")
      end
    end

    # Analyzes batches of solr records and computes overlap
    class Analyzer < Workflows::OverlapAnalyzer
      def initialize(input, report_record_class: Overlap::CombinedReportRecord)
        super
      end
    end

    # The writer:
    # * reads all output files from the analyzer
    # * collates to an individual output report by organization
    # * uploads each organization's overlap report to dropbox.
    class Writer < Workflows::OverlapWriter
      def initialize(working_directory:, report_record_class: Overlap::ReportRecord)
        super

        @reports = Hash.new do |h, organization|
          h[organization] = Zlib::GzipWriter.open(report_gz_path(organization)).tap do |gz|
            gz.puts(header)
            Services.logger.info("Opening report #{gz.path} for #{organization}")
          end
        end
      end

      def notification_message
        "Overlap reports complete"
      end

      def collate_report
        Dir.glob(File.join(working_directory, "*.overlap.tsv")).each do |rpt|
          Services.logger.info("Collating overlaps from #{rpt}")
          File.open(rpt).each_line do |line|
            fields = line.strip.split("\t")
            organization = fields.shift
            @reports[organization].puts(fields.join("\t"))
          end
        end
      end

      def finalize_report
        @reports.each do |organization, fh|
          fh.close
          Services.logger.info("Copying #{fh.path} to #{persistent_report_path}")
          FileUtils.cp(fh.path, persistent_report_path)
          rclone_move(fh.path, organization)
        end
      end
    end
  end
end
