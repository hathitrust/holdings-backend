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
  class ETASOverlap
    attr_accessor :organization, :ocn, :local_id, :item_type, :rights, :access,
      :catalog_id, :volume_id, :enum_chron

    def initialize(organization:, ocn:, local_id:, item_type: "", rights: "", access: "",
      catalog_id: "", volume_id: "", enum_chron: "")
      @organization = organization
      @ocn = ocn
      @local_id = local_id
      @item_type = item_type || ""
      @rights = rights || ""
      @access = convert_access(rights, access, organization) || ""
      @catalog_id = catalog_id || ""
      @volume_id = volume_id || ""
      @enum_chron = enum_chron || ""
    end

    def to_s
      [ocn,
        local_id,
        item_type,
        rights,
        access,
        catalog_id,
        volume_id,
        enum_chron].join("\t")
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
