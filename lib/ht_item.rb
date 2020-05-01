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
  validates :item_id, uniqueness: true
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
      h = to_hash
      delete
      new_parent.ht_items.create(h)
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
