# frozen_string_literal: true

require "mongoid"

# An HT Item
# - ocns
# - item_id
# - ht_bib_key
# - rights
# - bib_fmt
class HtItem
  include Mongoid::Document
  field :ocns, type: Array
  field :item_id, type: String
  field :ht_bib_key, type: Integer
  field :rights, type: String
  field :bib_fmt, type: String

  embedded_in :cluster
  validates_presence_of :ocns, :item_id, :ht_bib_key, :rights, :bib_fmt
  validates_each :ocns do |record, attr, value|
    value.each do |ocn|
      record.errors.add attr, "must be an integer" \
        unless (ocn.to_i if /\A[+-]?\d+\Z/.match?(ocn.to_s))
    end
  end

  # Attach this embedded document to another parent
  #
  # @param new_parent, the parent cluster to attach to
  def move(new_parent)
    unless new_parent.id == _parent.id
      new_parent.ht_items << dup
      delete
    end
  end

end
