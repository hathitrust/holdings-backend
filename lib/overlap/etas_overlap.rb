# frozen_string_literal: true

module Overlap
  # - ocn
  # - local_id
  # - format
  # - access
  # - rights
  class ETASOverlap
    attr_accessor :ocn, :local_id, :item_type, :rights, :access

    def initialize(ocn:, local_id:, item_type:, rights:, access:)
      @ocn = ocn
      @local_id = local_id
      @item_type = convert_format(item_type)
      @rights = rights
      @access = access
    end

    def to_s
      [ocn,
       local_id,
       item_type,
       rights,
       access].join("\t")
    end

    def convert_format(item_type = nil)
      case item_type || @item_type
      when "spm"
        "mono"
      when "mpm"
        "multi"
      when "ser", "ser/spm"
        "serial"
      end
    end
  end
end
