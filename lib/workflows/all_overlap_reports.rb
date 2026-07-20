# frozen_string_literal: true

require "services"
require "overlap/cluster_overlap"
require "overlap/report_record"
require "overlap/report_record_matching_members_count"
require "utils/slack_notifier"
require "workflows/map_reduce"
require "workflows/solr"

module Workflows
  module AllOverlapReports
    class DataSource < Workflows::Solr::DataSource

      # single-org overlap iterates through holdings & queries solr by ocn,
      # then finds unmatched OCNs in that set. could do that same approach if a
      # second phase to find unmatched OCNs doesn't work
      #
      # looks like getting distinct holdings ocns from the database table
      # shouldn't be that slow (iterating through holdings is getting about
      # 5000 distinct OCNs/second), so maybe worth doing that up front &
      # comparing against attested OCNs. that is, we dump all the records, then
      # we gather up all the attested OCNs in both holdings & items and compare.
      #
      # but let's start with getting all the overlaps for matching OCNs
      
      def dump_records(output_filename)
        with_milemarked_output(output_filename) do |output_record|
          cursorstream { |s| s.filters = ["deleted:false"] }.each do |record|
            output_record.call(record)
          end
        end

        # collect all OCNs from solr & sort
        # get all OCNs from holdings (TBD - current dump from mariadb)
        # run comm
        # append these non-matching holdings to output_filename

      end
    end

    # Analyzes batches of solr records and computes overlap
    class Analyzer < Workflows::Solr::Analyzer
      attr_reader :input, :report_record_class

      def initialize(input, report_record_class: Overlap::CombinedReportRecord)
        @input = input
        @report_record_class = MapReduce.to_class(report_record_class)
      end

      def run
        output = input + ".overlap.tsv"

        File.open(output, "w") do |output|
          @output = output

          records_from_file(input).each do |record|
            Services.logger.debug("Processing overlaps for #{record.cluster.ocns}")
            holdings_matched = write_overlaps(record.cluster)
            write_records_for_unmatched_holdings(record.cluster, holdings_matched)
          end
        end
      end

      def write_overlaps(cluster)
        holdings_matched = Set.new
        records_written = Set.new
        Overlap::ClusterOverlap.new(cluster).each do |overlap|
          overlap.matching_holdings.each do |holding|
            holdings_matched << holding
            report_record = report_record_class.new(holding: holding, ht_item: overlap.ht_item)
            output.puts(report_record) unless records_written.include? report_record.to_s
            records_written << report_record.to_s
          end
        end
        holdings_matched
      end

      def write_records_for_unmatched_holdings(cluster, holdings_matched)
        records_written = Set.new
        missed_holdings(cluster, holdings_matched).each do |holding|
          report_record = report_record_class.new(holding: holding)
          next if records_written.include? report_record.to_s

          records_written << report_record.to_s
          output.puts(report_record)
        end
      end

      # Holdings with org/local_id not found in holdings_matched
      #
      # @param cluster [Cluster]
      # @param holdings_matched [Set] set of holdings that did match an item
      def missed_holdings(cluster, holdings_matched)
        org_local_ids = Set.new(holdings_matched.map { |h| [h.organization, h.local_id] })
        cluster.holdings.reject do |h|
          org_local_ids.include? [h.organization, h.local_id]
        end || []
      end

      private

      attr_reader :output, :milemarker
    end

    # Merges output files from Analyzer together and uploads to dropbox
    class Writer
      # need to fan out by organization
      def initialize(working_directory:, report_record_class: Overlap::ReportRecord)
        @working_directory = working_directory
        @local_report_path = Settings.local_report_path || "local_reports"
        @report_record_class = MapReduce.to_class(report_record_class)
        Dir.mkdir(@local_report_path) unless File.exist?(@local_report_path)
        # persistent storage
        @persistent_report_path = Settings.overlap_reports_path
        Dir.mkdir(@persistent_report_path) unless File.exist?(@persistent_report_path)
        # public access location
        @remote_report_path = Settings.overlap_reports_remote_path

        @reports = Hash.new do |h,organization|
          h[organization] = Zlib::GzipWriter.open(report_gz_path(organization)).tap do |gz|
            gz.puts(header)
            Services.logger.info("Opening report #{gz.path} for #{organization}")
          end
        end
      end

      def run
        if Dir.glob(File.join(working_directory, "*.overlap.tsv")).empty?
          raise "No overlap report files found in #{working_directory}"
        end
        collate_report
        finalize_report
      end

      def finalize_report
        @reports.each do |organization,fh|
          fh.close
          Services.logger.info("Copying #{fh.path} to #{persistent_report_path}")
          FileUtils.cp(fh.path, persistent_report_path)
          system(*rclone_move(fh.path, organization))
        end
      end

      def notify
        message = "Overlap reports complete"
        Utils::SlackNotifier.post(message)
      end

      def header
        report_record_class.header
      end

      def report_filename(organization)
        nonus = (Services.ht_organizations[organization]&.country_code == "us") ? "" : "_nonus"
        @report_filename = "overlap_#{organization}_#{Date.today}#{nonus}.tsv.gz"
      end

      private

      attr_reader :local_report_path, :persistent_report_path, :remote_report_path, :organization, :working_directory, :report_record_class

      def report_gz_path(organization)
        File.join(local_report_path, report_filename(organization))
      end

      def collate_report
        Dir.glob(File.join(working_directory, "*.overlap.tsv")).each do |rpt|
          File.open(rpt).each_line do |line|
            fields = line.strip.split("\t")
            organization = fields.shift
            @reports[organization].puts(fields.join("\t"))
          end
        end
      end

      def dropbox_url
        "#{Settings.overlap_reports_remote_path_url}/#{organization}-hathitrust-member-data/analysis/#{report_filename}"
      end

      def rclone_move(file, org)
        remote_path = "#{@remote_report_path}/#{org}-hathitrust-member-data/analysis"
        Services.logger.info("Uploading #{file} to #{remote_path}")
        ["rclone", "--config", Settings.rclone_config_path, "move", File.path(file), remote_path]
      end
    end
  end
end
