# frozen_string_literal: true

require "mongoid"
require "enum_chron_parser"
require "services"

# An HT Item
# - ocns
# - item_id
# - ht_bib_key
# - rights
# - bib_fmt
# - enum_chron
# - n_enum
# - n_chron
# - collection_code
# - billing_entity
class HtItem
  include Mongoid::Document
  field :ocns, type: Array, default: []
  field :item_id, type: String
  field :ht_bib_key, type: Integer
  field :rights, type: String
  field :access, type: String
  field :bib_fmt, type: String
  field :enum_chron, type: String
  field :n_enum, type: String
  field :n_chron, type: String
  field :collection_code, type: String
  field :billing_entity, type: String

  embedded_in :cluster
  validates :item_id, uniqueness: true
  validates_presence_of :item_id, :ht_bib_key, :rights, :bib_fmt, :access

  #validates_each :ocns do |record, attr, value|
  #  value.each do |ocn|
  #    record.errors.add attr, "must be an integer" \
  #      unless (ocn.to_i if /\A[+-]?\d+\Z/.match?(ocn.to_s))
  #  end
  #end

  def initialize(params = nil)
    super
    normalize_enum_chron
    set_billing_entity if collection_code
  end

  def collection_code=(collection_code)
    super
    set_billing_entity
  end

  def normalize_enum_chron
    # When created with an enumchron, normalize it into separate
    # n_enum and n_chron
    unless enum_chron.nil?
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
      access:     access,
      bib_fmt:    bib_fmt,
      enum_chron: enum_chron,
      n_enum:     n_enum,
      n_chron:    n_chron
    }
  end

  private

  def set_billing_entity
    self.billing_entity = Services.ht_collections[collection_code].billing_entity
  end

end
