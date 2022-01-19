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
    attr_accessor :ocn, :local_id, :item_type, :rights, :access,
                  :catalog_id, :volume_id, :enum_chron

    def initialize(ocn:, local_id:, item_type:, rights:, access:,
      catalog_id:, volume_id:, enum_chron:)
      @ocn = ocn
      @local_id = local_id
      @item_type = item_type
      @rights = rights
      @access = access
      @catalog_id = catalog_id
      @volume_id = volume_id
      @enum_chron = enum_chron
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

  end
end
