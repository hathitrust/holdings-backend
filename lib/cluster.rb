# frozen_string_literal: true

require "mongoid"
require "holding"
require "ht_item"
require "commitment"
require "ocn_resolution"
require "serial"

# A set of identifiers (e.g. OCLC numbers),
# - ocns
# - holdings
# - htitems
# - serials
# - commitments
class Cluster
  include Mongoid::Document
  store_in collection: "clusters", database: "test", client: "default"
  field :ocns
  embeds_many :holdings, class_name: "Holding"
  embeds_many :ht_items, class_name: "HtItem"
  embeds_many :ocn_resolutions, class_name: "OCNResolution"
  embeds_many :serials, class_name: "Serial"
  embeds_many :commitments
  index({ ocns: 1 },
        unique: true,
        partial_filter_expression: { "ocns.0": { :$exists => true } })
  index({ "ht_items.item_id": 1 }, unique: true, sparse: true)
  index({ "ocn_resolutions.ocns": 1 }, unique: true, sparse: true)
  scope :for_resolution, lambda {|resolution|
    where(:ocns.in => [resolution.deprecated, resolution.resolved])
  }

  validates_each :ocns do |record, attr, value|
    value.each do |ocn|
      record.errors.add attr, "must be an integer" \
        unless (ocn.to_i if /\A[+-]?\d+\Z/.match?(ocn.to_s))
    end
    # ocns are a superset of ht_items.ocns
    record.errors.add attr, "must contain all ocns" \
      if (record.ht_items.collect(&:ocns).flatten +
          record.ocn_resolutions.collect(&:ocns).flatten - value).any?
  end

  # Adds the members of the given cluster to this cluster.
  # Deletes the other cluster.
  #
  # @param other The cluster whose members to merge with this cluster.
  # @return This cluster
  def merge(other)
    self.ocns = (ocns + other.ocns).sort.uniq
    move_members_to_self(other)
    other.delete
    self
  end

  # Merges multiple clusters together
  #
  # @param clusters All the clusters we need to merge
  # @return a cluster or nil if nil set
  def self.merge_many(clusters)
    c = clusters.shift
    clusters.each do |c2|
      c.merge(c2) unless c._id == c2._id
    end
    c&.save
    c
  end

  # Collects OCNs from embedded documents
  def collect_ocns
    (ocn_resolutions.collect(&:ocns).flatten +
    ht_items.collect(&:ocns).flatten +
    holdings.collect(&:ocn).flatten).uniq
  end

  private

  # Moves embedded documents from another cluster to itself
  #
  # @param other - the other cluster
  def move_members_to_self(other)
    other.holdings.each {|h| ClusterHolding.new(h).move(self) }
    other.ht_items.each {|ht| ClusterHtItem.new(ht).move(self) }
    other.commitments.each {|c| c.move(self) }
  end

end
