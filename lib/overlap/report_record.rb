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

    def initialize(holding: nil, overlap: nil, ht_item: overlap&.ht_item)
      @organization = holding.organization
      @ocn = holding.ocn
      @local_id = holding.local_id
      @item_type = holding&.mono_multi_serial
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
  end
end
