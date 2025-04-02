# frozen_string_literal: true

require "services"
require "cluster"
require "overlap/cluster_overlap"
require "overlap/report_record"
require "solr/cursorstream"

module Reports
  # Generates overlap report for an organization
  class OverlapReport
    attr_accessor :date_of_report, :local_report_path, :persistent_report_path, :remote_report_path, :organization

    SOLR_SLICE_SIZE = 500

    def initialize(organization)
      @date_of_report = Time.now.strftime("%Y-%m-%d")
      # where we write them on the pod
      @local_report_path = Settings.local_report_path || "local_reports"
      Dir.mkdir(@local_report_path) unless File.exist?(@local_report_path)
      # persistent storage
      @persistent_report_path = Settings.overlap_reports_path
      Dir.mkdir(@persistent_report_path) unless File.exist?(@persistent_report_path)
      # public access location
      @remote_report_path = Settings.overlap_reports_remote_path
      @organization = organization
    end

    def open_report(date)
      nonus = (Services.ht_organizations[organization]&.country_code == "us") ? "" : "_nonus"
      File.open("#{local_report_path}/overlap_#{organization}_#{date}#{nonus}.tsv", "w")
    end

    def report
      @report ||= open_report(date_of_report).tap do |fh|
        fh.puts header
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

    # Creates an overlap record and writes to the appropriate org file
    #
    # @param holding [Holding] the holdings provides the ocn, local_id, and organization
    # @param fields  [Hash] rights, access, catalog_id, volume_id, enum_chron
    def write_record(record)
      return unless organization == record.organization

      report.puts record
    end

    def write_overlaps(cluster, organization)
      holdings_matched = Set.new
      records_written = Set.new
      Overlap::ClusterOverlap.new(cluster, organization).each do |overlap|
        overlap.matching_holdings.each do |holding|
          holdings_matched << holding
          report_record = Overlap::ReportRecord.new(organization: holding.organization,
            ocn: holding.ocn, local_id: holding.local_id, item_type: holding.mono_multi_serial,
            rights:     overlap.ht_item.rights, access:     overlap.ht_item.access,
            catalog_id: overlap.ht_item.ht_bib_key, volume_id:  overlap.ht_item.item_id,
            enum_chron: overlap.ht_item.enum_chron)

          write_record(report_record) unless records_written.include? report_record.to_s
          records_written << report_record.to_s
        end
      end
      holdings_matched
    end

    def run
      dump_solr_records
      analyze_solr_records
      move_report
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

    def gzip_report(rpt)
      rpt.close
      zipped = File.path(rpt) + ".gz"
      Zlib::GzipWriter.open(zipped) do |gz|
        File.open(rpt) do |file|
          gz.mtime = File.mtime(file)
          while (chunk = file.read(16 * 1024))
            gz.write(chunk)
          end
        end
      end
      zipped
    end

    # Gzips, copies to persistent storage and rclones the report
    def move_report
      gz = gzip_report(report)
      FileUtils.cp(gz, @persistent_report_path)
      system(*rclone_move(gz, organization))
    end

    def rclone_move(file, org)
      ["rclone", "--config", Settings.rclone_config_path, "move",
        File.path(file),
        "#{@remote_report_path}/#{org}-hathitrust-member-data/analysis"]
    end

    private

    # TODO refactor duplication
    def default_working_directory
      work_base = File.join(@local_report_path, "work")
      FileUtils.mkdir_p(work_base)
      Dir.mktmpdir("estimate_", work_base)
    end

    def allrecords_ndj
      @allrecords_ndj ||= File.join(default_working_directory, "allrecords.ndj")
    end

    # TODO probably need to parallelize this part
    def analyze_solr_records
      milemarker = Milemarker.new(batch_size: 1000, name: "compile overlap report")
      milemarker.logger = Services.logger
      File.open(allrecords_ndj).each_slice(SOLR_SLICE_SIZE) do |lines|
        SolrBatch.new(lines, organization: organization).records.each do |record|
          record.ht_items
          Services.logger.debug("Processing overlaps for #{record.cluster.ocns}")
          holdings_matched = write_overlaps(record.cluster, organization)
          write_records_for_unmatched_holdings(record.cluster, holdings_matched)
          milemarker.increment_and_log_batch_line
        end
        Thread.pass
      end
      milemarker.log_final_line
    end

    def dump_solr_records
      core_url = ENV["SOLR_URL"]
      milemarker = Milemarker.new(batch_size: 1000, name: "get solr records")
      milemarker.logger = Services.logger
      solr_records_seen = Set.new

      File.open(allrecords_ndj, "w") do |out|
        Clusterable::Holding.for_organization(organization)
          # TODO fixme setting for batch size
          .each_slice(100) do |holdings_batch|
            ocn_batch = holdings_batch.map(&:ocn)

            matched_ocns = Set.new

            # TODO refactor duplication
            # TODO try querying for held records - any faster?
            Solr::CursorStream.new(url: core_url) do |s|
              s.fields = %w[ht_json id oclc oclc_search title format]
              s.filters = ["oclc_search:(#{ocn_batch.join(" ")})"]
              s.batch_size = 5000
            end.each do |record|
              next if solr_records_seen.include?(record["id"])
              solr_records_seen.add(record["id"])
              matched_ocns.merge(record["oclc_search"].map(&:to_i))
              out.puts record.to_json
              milemarker.increment_and_log_batch_line
            end

            # stub result for ocns that didn't match anything in this batch,
            # so we can write overlap records for unmatched holdings
            ocn_batch.to_set.subtract(matched_ocns).each do |unmatched_ocn|
              out.puts({
                format: "Unknown",
                oclc_search: [unmatched_ocn],
                ht_json: "[]"
              }.to_json)
            end
          end
      end

      milemarker.log_final_line
    end
  end
end
