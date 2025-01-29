# frozen_string_literal: true

require "enum_chron_parser"

# Handles automatic normalization of enum_chron fields for Holdings and HTItems
module EnumChron
  def self.included(base)
    base.attr_writer :n_enum, :n_chron, :n_enum_chron
    # we define the reader and the writer
    base.add_attrs :enum_chron
  end

  def n_enum
    @n_enum ||= ""
  end

  def n_chron
    @n_chron ||= ""
  end

  def n_enum_chron
    @n_enum_chron ||= ""
  end

  def enum_chron
    @enum_chron ||= ""
  end

  def enum_chron=(enum_chron)
    @enum_chron = enum_chron
    normalize_enum_chron
  end

  def normalize_enum_chron
    # normalize into separate n_enum and n_chron
    ec_parser = EnumChronParser.new
    ec_parser.parse(enum_chron.to_s || "")
    @n_enum = ec_parser.normalized_enum || ""
    @n_chron = ec_parser.normalized_chron || ""
    @n_enum_chron = [n_enum, n_chron].join("\t").sub(/^\t$/, "")
  end
end
