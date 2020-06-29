# frozen_string_literal: true

require "mongoid"
require "enum_chron_parser"

# An HT Item
# - ocns
# - item_id
# - ht_bib_key
# - rights
# - bib_fmt
# - enum_chron
# - n_enum
# - n_chron

class HtItem
  include Mongoid::Document
  field :ocns, type: Array, default: []
  field :item_id, type: String
  field :ht_bib_key, type: Integer
  field :rights, type: String
  field :bib_fmt, type: String
  field :enum_chron, type: String
  field :n_enum, type: String
  field :n_chron, type: String

  embedded_in :cluster
  validates :item_id, uniqueness: true
  validates_presence_of :item_id, :ht_bib_key, :rights, :bib_fmt

  validates_each :ocns do |record, attr, value|
    value.each do |ocn|
      record.errors.add attr, "must be an integer" \
        unless (ocn.to_i if /\A[+-]?\d+\Z/.match?(ocn.to_s))
    end
  end

  def initialize(params=nil)
    super
    normalize_enum_chron
  end

  def normalize_enum_chron
    # When created with an enumchron, normalize it into separate
    # n_enum and n_chron
    if !enum_chron.nil?
      ec_parser = EnumChronParser.new
      ec_parser.parse(enum_chron)
      self.n_enum  = ec_parser.normalized_enum
      self.n_chron = ec_parser.normalized_chron
    end
  end

  def to_hash
    {
      ocns:       ocns,
      item_id:    item_id,
      ht_bib_key: ht_bib_key,
      rights:     rights,
      bib_fmt:    bib_fmt,
      enum_chron: enum_chron,
      n_enum:     n_enum,
      n_chron:    n_chron
    }
  end
end
