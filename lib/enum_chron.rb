# frozen_string_literal: true

require "enum_chron_parser"
require "services"

# Handles automatic normalization of enum_chron fields for Holdings and HTItems
module EnumChron
  def initialize(params = nil)
    params ||= {}
    params[:enum_chron] ||= ""
    super
  end

  def enum_chron=(enum_chron)
    super
    normalize_enum_chron
  end

  def normalize_enum_chron
    # normalize into separate n_enum and n_chron
    ec_parser = EnumChronParser.new
    ec_parser.parse(enum_chron || "")
    self.n_enum = ec_parser.normalized_enum || ""
    self.n_chron = ec_parser.normalized_chron || ""
    self.n_enum_chron = [n_enum, n_chron].join("\t").sub(/^\t$/, "")
  end
end
