# frozen_string_literal: true

require "mongoid"

# An HT Item
# - ocns
# - item_id
# - ht_bib_key
# - rights
# - bib_fmt
# - enum_chron
class HtItem
  include Mongoid::Document
  field :ocns, type: Array
  field :item_id, type: String
  field :ht_bib_key, type: Integer
  field :rights, type: String
  field :bib_fmt, type: String
  field :enum_chron, type: String

  embedded_in :cluster
  validates :item_id, uniqueness: true
  validates_presence_of :ocns, :item_id, :ht_bib_key, :rights, :bib_fmt
  validates_each :ocns do |record, attr, value|
    value.each do |ocn|
      record.errors.add attr, "must be an integer" \
        unless (ocn.to_i if /\A[+-]?\d+\Z/.match?(ocn.to_s))
    end
  end

  def to_hash
    {
      ocns:       ocns,
      item_id:    item_id,
      ht_bib_key: ht_bib_key,
      rights:     rights,
      bib_fmt:    bib_fmt
    }
  end

end
