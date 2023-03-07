# frozen_string_literal: true

require "services"
require "cluster"
require "overlap/cluster_overlap"
require "overlap/etas_overlap"
require "utils/session_keep_alive"

module Reports
  # Generates overlap reports for 1 or all organizations
  class EtasOrganizationOverlapReport
    attr_accessor :reports, :date_of_report, :local_report_path, :persistent_report_path, :remote_report_path, :organization

    def initialize(organization = nil)
      @reports = {}
      @date_of_report = Time.now.strftime("%Y-%m-%d")
      # where we write them on the pod
      @local_report_path = Settings.local_report_path || "local_reports"
      Dir.mkdir(@local_report_path) unless File.exist?(@local_report_path)
      # persistent storage
      @persistent_report_path = Settings.etas_overlap_reports_path
      Dir.mkdir(@persistent_report_path) unless File.exist?(@persistent_report_path)
      # public access location
      @remote_report_path = Settings.etas_overlap_reports_remote_path
      @organization = organization
    end

    def open_report(org, date)
      nonus = Services.ht_organizations[org]&.country_code == "us" ? "" : "_nonus"
      File.open("#{local_report_path}/etas_overlap_#{org}_#{date}#{nonus}.tsv", "w")
    end

    def report_for_org(org)
      unless reports.key?(org)
        reports[org] = open_report(org, date_of_report)
        reports[org].puts header
      end
      reports[org]
    end

    def clusters_with_holdings
      Utils::SessionKeepAlive.new(120).run do
        if organization.nil?
          Cluster.batch_size(Settings.etas_overlap_batch_size)
            .where("holdings.0": {"$exists": 1}).no_timeout.pluck(:_id).to_a
        else
          Cluster.batch_size(Settings.etas_overlap_batch_size)
            .where("holdings.organization": organization).no_timeout.pluck(:_id).to_a
        end
      end
    end

    # Holdings with org/local_id not found in holdings_matched
    #
    # @param cluster [Cluster]
    # @param holdings_matched [Set] set of holdings that did match an item
    def missed_holdings(cluster, holdings_matched)
      org_local_ids = Set.new(holdings_matched.pluck(:organization, :local_id))
      if organization.nil?
        cluster.holdings.reject { |h| org_local_ids.include? [h.organization, h.local_id] }
      else
        cluster.holdings.group_by(&:organization)[organization].reject do |h|
          org_local_ids.include? [h.organization, h.local_id]
        end
      end
    end

    # Creates an overlap record and writes to the appropriate org file
    #
    # @param holding [Holding] the holdings provides the ocn, local_id, and organization
    # @param fields  [Hash] rights, access, catalog_id, volume_id, enum_chron
    def write_record(record)
      return unless organization.nil? || organization == record.organization

      report_for_org(record.organization).puts record
    end

    def write_overlaps(cluster, organization)
      holdings_matched = Set.new
      records_written = Set.new
      Overlap::ClusterOverlap.new(cluster, organization).each do |overlap|
        overlap.matching_holdings.each do |holding|
          holdings_matched << holding
          etas_record = Overlap::ETASOverlap.new(organization: holding.organization,
            ocn: holding.ocn, local_id: holding.local_id, item_type: holding.mono_multi_serial,
            rights:     overlap.ht_item.rights, access:     overlap.ht_item.access,
            catalog_id: overlap.ht_item.ht_bib_key, volume_id:  overlap.ht_item.item_id,
            enum_chron: overlap.ht_item.enum_chron)

          write_record(etas_record) unless records_written.include? etas_record.to_s
          records_written << etas_record.to_s
        end
      end
      holdings_matched
    end

    def run
      clusters_with_holdings.each do |c|
        cluster = Cluster.find_by(_id: c)
        next if cluster.nil?
        holdings_matched = write_overlaps(cluster, organization)
        write_records_for_unmatched_holdings(cluster, holdings_matched)
        Thread.pass
      end
      move_reports
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
        etas_record = Overlap::ETASOverlap.new(organization: holding.organization,
          ocn: holding.ocn,
          local_id: holding.local_id,
          item_type: holding.mono_multi_serial)
        next if records_written.include? etas_record.to_s

        records_written << etas_record.to_s
        write_record(etas_record)
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

    # Gzips, copies to persistent storage and rclones the reports
    def move_reports
      reports.each do |org, file|
        next unless org == organization || organization.nil?

        gz = gzip_report(file)
        FileUtils.cp(gz, @persistent_report_path)
        system(*rclone_move(gz, org))
      end
    end

    def rclone_move(file, org)
      ["rclone", "--config", Settings.rclone_config_path, "move",
        File.path(file),
        "#{@remote_report_path}/#{org}-hathitrust-member-data/analysis"]
    end
  end
end
