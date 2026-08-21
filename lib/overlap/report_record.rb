# frozen_string_literal: true

module Overlap
  # - ocn
  # - local_id
  # - item_type
  # - rights
  # - access
  # - catalog_id
  # - volume_id
  # - enum_chron
  class ReportRecord
    attr_reader :organization, :ocn, :local_id, :item_type, :rights, :access,
      :catalog_id, :volume_id, :enum_chron

    def initialize(holdings:, organization:, ht_item: nil)
      @organization = organization

      @ocn = holdings.map(&:ocn).uniq.sort.join(",")
      @local_id = holdings.map(&:local_id).uniq.sort.join(",")
      @item_type = holdings.map(&:mono_multi_serial).uniq.sort.join(",")

      @rights = ht_item&.rights || ""
      @access = convert_access(rights, ht_item&.access, organization) || ""
      @catalog_id = ht_item&.ht_bib_key || ""
      @volume_id = ht_item&.item_id || ""
      @enum_chron = ht_item&.enum_chron || ""
    end

    def fields
      [ocn,
        local_id,
        item_type,
        rights,
        access,
        catalog_id,
        volume_id,
        enum_chron]
    end

    def to_s
      fields.join("\t")
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

    def self.header_fields
      ["oclc",
        "local_id",
        "item_type",
        "rights",
        "access",
        "catalog_id",
        "volume_id",
        "enum_chron"]
    end

    def self.header
      header_fields.join("\t")
    end
  end

  class CombinedReportRecord < ReportRecord
    def fields
      [organization] + super
    end
  end
end
