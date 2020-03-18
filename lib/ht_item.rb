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
  index({ item_id: 1 }, unique: true)
  validates_presence_of :ocns, :item_id, :ht_bib_key, :rights, :bib_fmt
  validates_each :ocns do |record, attr, value|
    value.each do |ocn|
      record.errors.add attr, "must be an integer" \
        unless (ocn.to_i if /\A[+-]?\d+\Z/.match?(ocn.to_s))
    end
  end

  # Prevent creation of duplicates
  #
  # @param record, a hash of values
  def initialize(record)
    raise Mongo::Error::OperationFailure, "Duplicate HT Item" if Cluster.where(
      "ht_items.item_id": record[:item_id]
    ).any?

    super
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

  # Add htitem to the clusters, merging if necessary
  #
  # @param record
  def self.add(record)
    c = Cluster.merge_many(Cluster.where(ocns: { "$in": record[:ocns] }))
    if c.nil?
      c = Cluster.new(ocns: record[:ocns])
      c.save
    end
    c.ht_items.create(record)
  end

  # Adds its own OCNs to its parent's
  def save
    _parent.ocns = (_parent.ocns + ocns).uniq
    super
  end

end
