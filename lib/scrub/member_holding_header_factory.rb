# frozen_string_literal: true

require "scrub/item_type_error"
require "scrub/member_holding_header"

MON = "mono"
MUL = "multi"
SER = "serial"

module Scrub
  # Usage:
  #
  # MemberHoldingHeaderFactory.for("mono", str)   -> MonoHoldingHeader
  # MemberHoldingHeaderFactory.for("multi", str)  -> MultiHoldingHeader
  # MemberHoldingHeaderFactory.for("serial", str) -> SerialHoldingHeader
  class MemberHoldingHeaderFactory
    # Return a proper subclass of MemberHoldingHeader
    def self.for(item_type, header_line)
      case item_type
      when MON
        MonoHoldingHeader.new(header_line)
      when MUL
        MultiHoldingHeader.new(header_line)
      when SER
        SerialHoldingHeader.new(header_line)
      else
        raise Scrub::ItemTypeError, "#{item_type} is not a valid item_type"
      end
    end
  end
end
