# frozen_string_literal: true

require "services"
require "cluster"
require "cluster_overlap"

module Report

  # Generates overlap reports for 1 or all members
  class EtasMemberOverlapReport
    attr_accessor :reports, :date_of_report, :report_path, :organization

    def initialize(organization = nil)
      @reports = {}
      @date_of_report = Time.now.strftime("%Y-%m-%d")
      @report_path = Settings.etas_overlap_reports_path || "tmp_reports"
      Dir.mkdir(@report_path) unless File.exist?(@report_path)
      @organization = organization
    end

    def open_report(org, date)
      File.open("#{report_path}/#{org}_#{date}.tsv", "w")
    end

    def report_for_org(org)
      unless reports.key?(org)
        reports[org] = open_report(org, date_of_report)
      end
      reports[org]
    end

    def clusters_with_holdings
      if organization.nil?
        Cluster.where("holdings.0": { "$exists": 1 }).no_timeout
      else
        Cluster.where("holdings.organization": organization).no_timeout
      end
    end

    def missed_holdings(cluster, holdings_matched)
      if organization.nil?
        cluster.holdings - holdings_matched.to_a
      else
        cluster.holdings.group_by(&:organization)[organization] - holdings_matched.to_a
      end
    end

    # Creates an overlap record and writes to the appropriate org file
    #
    # @param holding [Holding] the holdings provides the ocn, local_id, and organization
    # @param format  [String] the cluster format, 'mpm', 'spm', 'ser', or 'ser/spm'
    # @param access  [String] 'allow' or 'deny' for the associated item
    # @param rights  [String] the rights for the associated item
    def write_record(holding, format, access, rights)
      etas_record = ETASOverlap.new(ocn: holding[:ocn],
                      local_id: holding[:local_id],
                      item_type: format,
                      access: access,
                      rights: rights)
      report_for_org(holding[:organization]).puts etas_record
    end

    def write_overlaps(cluster, organization)
      holdings_matched = Set.new
      ClusterOverlap.new(cluster, organization).each do |overlap|
        overlap.matching_holdings.each do |holding|
          holdings_matched << holding
          write_record(holding, cluster.format, overlap.ht_item.access, overlap.ht_item.rights)
        end
      end
      holdings_matched
    end

    def run
      clusters_with_holdings.each do |c|
        # No ht_items means an empty line for each holding
        unless c.ht_items.any?
          c.holdings.each {|holding| write_record(holding, c.format, "", "") }
          next
        end
        holdings_matched = write_overlaps(c, organization)
        missed_holdings(c, holdings_matched).each do |holding|
          write_record(holding, c.format, "", "")
        end
      end
    end
  end
end
