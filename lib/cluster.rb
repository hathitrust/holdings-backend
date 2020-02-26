# frozen_string_literal: true

require "forwardable"
require "mongoid"
require "holding"
require "htitem"
require "commitment"
require "services"

# A set of identifiers (e.g. OCLC numbers),
# - ocns
# - holdings
# - htitems
# - commitments
class Cluster
  include Mongoid::Document
  store_in collection: "clusters", database: "test", client: "default"
  field :ocns, type: Array
  embeds_many :holdings, class_name: "Holding"
  embeds_many :h_t_items
  embeds_many :commitments

  def initialize(*args)
    super
  end

  # Adds the members of the given cluster to this cluster.
  # Deletes the other cluster.
  #
  # @param other The cluster whose members to merge with this cluster.
  # @return This cluster
  def merge(other)
    self.ocns = (ocns + other.ocns).sort.uniq
    other.holdings.each {|h| h.move(self) }
    other.h_t_items.each {|ht| ht.move(self) }
    other.commitments.each {|c| c.move(self) }
    other.delete
    self
  end

  def save
    Cluster.where(ocns: { "$in": ocns }).each do |c|
      unless c._id == _id
        merge(c)
      end
    end
    super
  end

end
