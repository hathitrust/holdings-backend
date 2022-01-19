# frozen_string_literal: true

require "services"
require "cluster"
require "overlap/cluster_overlap"
require "overlap/etas_overlap"

module Reports

  # Generates overlap reports for 1 or all organizations
  class EtasOrganizationOverlapReport
    attr_accessor :reports, :date_of_report, :report_path, :organization

    def initialize(organization = nil)
      @reports = {}
      @date_of_report = Time.now.strftime("%Y-%m-%d")
      @report_path = Settings.etas_overlap_reports_path || "tmp_reports"
      Dir.mkdir(@report_path) unless File.exist?(@report_path)
      @organization = organization
    end

    def open_report(org, date)
      nonus = Services.ht_organizations[org]&.country_code == "us" ? "" : "_nonus"
      File.open("#{report_path}/#{org}_#{date}#{nonus}.tsv", "w")
    end

    def report_for_org(org)
      unless reports.key?(org)
        reports[org] = open_report(org, date_of_report)
        reports[org].puts header
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
    # @param fields  [Hash] rights, access, catalog_id, volume_id, enum_chron
    def write_record(holding, fields)
      return unless organization.nil? || organization == holding[:organization]

      etas_record = Overlap::ETASOverlap.new(ocn: holding[:ocn],
                      local_id: holding[:local_id],
                      item_type: holding.mono_multi_serial,
                      rights: fields[:rights],
                      access: convert_access(fields[:rights], fields[:access],
                                             holding[:organization]),
                      catalog_id: fields[:catalog_id],
                      volume_id: fields[:volume_id],
                      enum_chron: fields[:enum_chron])
      report_for_org(holding[:organization]).puts etas_record
    end

    def write_overlaps(cluster, organization)
      holdings_matched = Set.new
      Overlap::ClusterOverlap.new(cluster, organization).each do |overlap|
        overlap.matching_holdings.each do |holding|
          holdings_matched << holding
          fields = { access:     overlap.ht_item.access,
                     rights:     overlap.ht_item.rights,
                     catalog_id: overlap.ht_item.ht_bib_key,
                     volume_id:  overlap.ht_item.item_id,
                     enum_chron: overlap.ht_item.enum_chron }
          write_record(holding, fields)
        end
      end
      holdings_matched
    end

    def run
      clusters_with_holdings.each do |c|
        # No ht_items means an empty line for each holding
        unless c.ht_items.any?
          fields = Hash.new ""
          c.holdings.each {|holding| write_record(holding, fields) }
          next
        end
        holdings_matched = write_overlaps(c, organization)
        missed_holdings(c, holdings_matched).each do |holding|
          write_record(holding, Hash.new(""))
        end
      end
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

    # Handles access allow/deny for non-us organizations
    def convert_access(rights, access, org)
      return access if Services.ht_organizations[org].country_code == "us"

      case rights
      when "pdus"
        access = "deny"
      when "icus"
        access = "allow"
      end
      access
    end
  end
end
