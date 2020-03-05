# frozen_string_literal: true

require "mongoid"
require "holding"
require "ht_item"
require "commitment"

# A set of identifiers (e.g. OCLC numbers),
# - ocns
# - holdings
# - htitems
# - commitments
class Cluster
  include Mongoid::Document
  store_in collection: "clusters", database: "test", client: "default"
  field :ocns
  embeds_many :holdings, class_name: "Holding"
  embeds_many :ht_items
  embeds_many :commitments
  index({ ocns: 1 }, unique: true)

  validates_each :ocns do |record, attr, value|
    value.each do |ocn|
      record.errors.add attr, "must be an integer" unless (ocn.to_i if ocn.to_s =~ /\A[+-]?\d+\Z/)
    end
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

  private

  def move_members_to_self(other)
    other.holdings.each {|h| h.move(self) }
    other.ht_items.each {|ht| ht.move(self) }
    other.commitments.each {|c| c.move(self) }
  end

end
