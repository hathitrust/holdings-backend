# frozen_string_literal: true

require "custom_errors"
require "member_holding_header"

# Usage:
#
# MemberHoldingHeaderFactory.new("mono", header_str)
#   .get_instance # -> MonoHoldingHeader
#
# MemberHoldingHeaderFactory.new("multi", header_str)
#   .get_instance # -> MultiHoldingHeader
#
# MemberHoldingHeaderFactory.new("serial", header_str)
#   .get_instance # -> SerialHoldingHeader
class MemberHoldingHeaderFactory
  MON = "mono"
  MUL = "multi"
  SER = "serial"

  def initialize(item_type, header_line)
    @item_type   = item_type
    @header_line = header_line
  end

  # Return a proper subclass of MemberHoldingHeader
  # rubocop:disable Naming/AccessorMethodName
  def get_instance
    case @item_type
    when MON
      MonoHoldingHeader.new(@header_line)
    when MUL
      MultiHoldingHeader.new(@header_line)
    when SER
      SerialHoldingHeader.new(@header_line)
    else
      raise ItemTypeError, "#{@item_type} is not a valid item_type"
    end
  end
  # rubocop:enable Naming/AccessorMethodName
end
