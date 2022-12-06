# frozen_string_literal: true

require "scrub/item_type_error"
require "scrub/member_holding_header"

module Scrub
  # Usage:
  # MemberHoldingHeaderFactory.for("mon", str) #-> MonHoldingHeader
  class MemberHoldingHeaderFactory
    # Return a proper subclass of MemberHoldingHeader
    def self.for(item_type, header_line)
      mix = "mix"
      mon = "mon"
      spm = "spm"
      mpm = "mpm"
      ser = "ser"

      case item_type
      when mix
        MixHoldingHeader
      when mon
        MonHoldingHeader
      when spm
        SpmHoldingHeader
      when mpm
        MpmHoldingHeader
      when ser
        SerHoldingHeader
      else
        raise Scrub::ItemTypeError,
          "#{item_type} is not a valid item_type"
      end.new(header_line)
    end
  end
end
