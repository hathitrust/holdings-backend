# frozen_string_literal: true

require "services"
require "overlap/cluster_overlap"
require "overlap/report_record"
require "workflows/solr"

module Workflows
  module OverlapReport
    class DataSource < Workflows::Solr::DataSource
      attr_reader :organization

      def initialize(organization:,
        ocns_per_solr_query: Settings.solr_data_source.ocns_per_solr_query)
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
    class Analyzer < Workflows::Solr::Analyzer
      attr_reader :input, :organization

      def initialize(input, organization:)
        @input = input
        @organization = organization
      end

      def run
        output = input + ".overlap.tsv"

        File.open(output, "w") do |output|
          @output = output

          records_from_file(input, organization: organization).each do |record|
            Services.logger.debug("Processing overlaps for #{record.cluster.ocns}")
            holdings_matched = write_overlaps(record.cluster, organization)
            write_records_for_unmatched_holdings(record.cluster, holdings_matched)
          end
        end
      end

      def write_record(record)
        return unless organization == record.organization

        output.puts record
      end

      def write_overlaps(cluster, organization)
        holdings_matched = Set.new
        records_written = Set.new
        Overlap::ClusterOverlap.new(cluster, organization).each do |overlap|
          overlap.matching_holdings.each do |holding|
            holdings_matched << holding
            report_record = Overlap::ReportRecord.new(
              organization: holding.organization,
              ocn: holding.ocn,
              local_id: holding.local_id,
              item_type: holding.mono_multi_serial,
              rights: overlap.ht_item.rights,
              access: overlap.ht_item.access,
              catalog_id: overlap.ht_item.ht_bib_key,
              volume_id: overlap.ht_item.item_id,
              enum_chron: overlap.ht_item.enum_chron
            )

            write_record(report_record) unless records_written.include? report_record.to_s
            records_written << report_record.to_s
          end
        end
        holdings_matched
      end

      def write_records_for_unmatched_holdings(cluster, holdings_matched)
        records_written = Set.new
        missed_holdings(cluster, holdings_matched).each do |holding|
          report_record = Overlap::ReportRecord.new(organization: holding.organization,
            ocn: holding.ocn,
            local_id: holding.local_id,
            item_type: holding.mono_multi_serial)
          next if records_written.include? report_record.to_s

          records_written << report_record.to_s
          write_record(report_record)
        end
      end

      # Holdings with org/local_id not found in holdings_matched
      #
      # @param cluster [Cluster]
      # @param holdings_matched [Set] set of holdings that did match an item
      def missed_holdings(cluster, holdings_matched)
        org_local_ids = Set.new(holdings_matched.map { |h| [h.organization, h.local_id] })
        cluster.holdings.group_by(&:organization)[organization]&.reject do |h|
          org_local_ids.include? [h.organization, h.local_id]
        end || []
      end

      private

      attr_reader :output, :milemarker
    end

    # Merges output files from Analyzer together and uploads to dropbox
    class Writer
      def initialize(organization:, working_directory:)
        @organization = organization
        @working_directory = working_directory
        @local_report_path = Settings.local_report_path || "local_reports"
        Dir.mkdir(@local_report_path) unless File.exist?(@local_report_path)
        # persistent storage
        @persistent_report_path = Settings.overlap_reports_path
        Dir.mkdir(@persistent_report_path) unless File.exist?(@persistent_report_path)
        # public access location
        @remote_report_path = Settings.overlap_reports_remote_path
      end

      def run
        gzip_report
        FileUtils.cp(report_gz_path, persistent_report_path)
        system(*rclone_move(report_gz_path, organization))
      end

      def header
        ["oclc",
          "local_id",
          "item_type",
          "rights",
          "access",
          "catalog_id",
          "volume_id",
          "enum_chron"].join("\t")
      end

      def report_filename
        return @report_filename if @report_filename

        nonus = (Services.ht_organizations[organization]&.country_code == "us") ? "" : "_nonus"
        @report_filename = "overlap_#{organization}_#{Date.today}#{nonus}.tsv.gz"
      end

      private

      attr_reader :local_report_path, :persistent_report_path, :remote_report_path, :organization, :working_directory

      def report_gz_path
        File.join(local_report_path, report_filename)
      end

      def gzip_report
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

      def rclone_move(file, org)
        ["rclone", "--config", Settings.rclone_config_path, "move",
          File.path(file),
          "#{@remote_report_path}/#{org}-hathitrust-member-data/analysis"]
      end
    end
  end
end
