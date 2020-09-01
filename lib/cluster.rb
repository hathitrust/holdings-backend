# frozen_string_literal: true

require "mongoid"
require "holding"
require "ht_item"
require "commitment"
require "ocn_resolution"
require "serial"
require "cluster_ht_item"

# Indication of a retryable error with clustering
class ClusterError < RuntimeError
end

# A set of identifiers (e.g. OCLC numbers),
# - ocns
# - holdings
# - htitems
# - serials
# - commitments
class Cluster
  include Mongoid::Document
  store_in collection: "clusters"
  field :ocns
  embeds_many :holdings, class_name: "Holding"
  embeds_many :ht_items, class_name: "HtItem"
  embeds_many :ocn_resolutions, class_name: "OCNResolution"
  embeds_many :serials, class_name: "Serial"
  embeds_many :commitments
  index({ ocns: 1 },
        unique: true,
        partial_filter_expression: { ocns: { :$gt => 0 } })
  index({ "ht_items.item_id": 1 }, unique: true, sparse: true)
  index({ "ocn_resolutions.ocns": 1 }, unique: true, sparse: true)
  scope :for_resolution, lambda {|resolution|
    where(:ocns.in => [resolution.deprecated, resolution.resolved])
  }
  scope :for_ocns, lambda { |ocns| where(:ocns.in => ocns) }
  scope :with_ht_item, lambda { |ht_item| where("ht_items.item_id": ht_item.item_id) }

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
    puts "Deleting cluster #{other._id}"
    other.delete
    self
  end

  # Merges all clusters in clusters into the given
  # destination cluster
  #
  # @parm clusters The clusters whose members to merge with this cluster
  # @return this cluster
  def merge_many(clusters)
    clusters.each do |source|
      raise ClusterError, "clusters disappeared, try again" if source.nil?
      merge(source) unless source._id == _id
    end
    save if changed?
    self
  end

  # Merges multiple clusters together
  #
  # @param clusters All the clusters we need to merge
  # @return a cluster or nil if nil set
  def self.merge_many(clusters,transaction: true)
    c = clusters.shift
    if(clusters.any?)
      raise ClusterError, "cluster disappeared, try again" if c.nil?

      if(transaction)
        c.with_session do |session|
          session.start_transaction
          c.merge_many(clusters)
          session.commit_transaction
        end
      else
        c.merge_many(clusters)
      end
    end
    c
  end

  # Collects OCNs from OCN resolutions and HT items
  def collect_ocns
    (ocn_resolutions.collect(&:ocns).flatten +
     ht_items.collect(&:ocns).flatten).uniq
  end

  # returns the first matching ht item by item id in this cluster, if any
  #
  # @param the item id to find
  def ht_item(item_id)
    ht_items.to_a.find { |h| h.item_id == item_id }
  end

  private

  # Moves embedded documents from another cluster to itself
  #
  # @param other - the other cluster
  def move_members_to_self(other)
    other.holdings.each {|h| ClusterHolding.new(h).move(self) }
    other.ht_items.each {|ht| ClusterHtItem.new(ht.ocns).move(ht,self) }
    other.commitments.each {|c| c.move(self) }
  end
end
