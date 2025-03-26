# frozen_string_literal: true

require "services"
require "cluster"
require "overlap/cluster_overlap"
require "overlap/report_record"

module Reports
  # Generates overlap reports for 1 or all organizations
  class OverlapReport
    attr_accessor :reports, :date_of_report, :local_report_path, :persistent_report_path, :remote_report_path, :organization

    def initialize(organization = nil)
      @reports = {}
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

      # TODO - this probably won't scale; would be better to iterate over
      # catalog records
      @ocns_seen = Set.new
    end

    def open_report(org, date)
      nonus = (Services.ht_organizations[org]&.country_code == "us") ? "" : "_nonus"
      File.open("#{local_report_path}/overlap_#{org}_#{date}#{nonus}.tsv", "w")
    end

    def report_for_org(org)
      unless reports.key?(org)
        reports[org] = open_report(org, date_of_report)
        reports[org].puts header
      end
      reports[org]
    end

    def clusters_with_holdings
      marker = Milemarker.new(batch_size: 1000)
      return to_enum(__method__) unless block_given?

      if organization.nil?
        Clusterable::Holding.all do |h|
          cluster = h.cluster
          next if cluster.ocns.any? { |o| @ocns_seen.include?(o) }
          @ocns_seen.merge(cluster.ocns)
          yield cluster
          marker.incr
          marker.on_batch { |m| Services.logger.info m.batch_line }
        end
      else
        Clusterable::Holding.for_organization(organization) do |h|
          cluster = h.cluster
          next if cluster.ocns.any? { |o| @ocns_seen.include?(o) }
          @ocns_seen.merge(cluster.ocns)
          yield cluster
          marker.incr
          marker.on_batch { |m| Services.logger.info m.batch_line }
        end
      end

      Services.logger.info marker.final_line
    end

    # Holdings with org/local_id not found in holdings_matched
    #
    # @param cluster [Cluster]
    # @param holdings_matched [Set] set of holdings that did match an item
    def missed_holdings(cluster, holdings_matched)
      org_local_ids = Set.new(holdings_matched.map { |h| [h.organization, h.local_id] })
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
      clusters_with_holdings.each do |cluster|
        Services.logger.debug("Processing overlaps for #{cluster.ocns}")
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
