# frozen_string_literal: true

require 'forwardable'
require 'mongoid'
require 'holding'
require 'htitem'
require 'commitment'
require 'services'

# A set of identifiers (e.g. OCLC numbers),
# - ocns
# - holdings
# - htitems
# - commitments
class Cluster
  include Mongoid::Document
  store_in collection: "clusters", database: "test", client: "default"
  field :ocns, type: Array
  embeds_many :holdings
  embeds_many :h_t_items
  embeds_many :commitments 

  attr_writer :holdings

  # Returns an empty array if no documents are embedded
  def embedded_field(field = __callee__)
    if instance_variable_get("@#{field}").nil? 
      []
    else
      instance_variable_get("@#{field}")
    end
  end
  alias holdings embedded_field
  alias h_t_items embedded_field
  alias commitments embedded_field

  # Combines two clusters into one
  #
  # @param first, second cluster documents
  def +(second)
    Cluster.new(ocns: (self.ocns + second.ocns).uniq,
                holdings: (self.holdings + second.holdings).uniq,
                h_t_items: (self.h_t_items + second.h_t_items).uniq,
                commitments: (self.commitments + second.commitments).uniq)
  end

  # Adds the members of the given cluster to this cluster.
  #
  # @param other The cluster whose members to merge with this cluster.
  # @return This cluster
  def merge(other)
    @ocns = (ocns + other.ocns).uniq
    @holdings = holdings + other.holdings
    @h_t_items = h_t_items + other.h_t_items
    @commitments = commitments + other.commitments
    #ocns = (ocns + other.ocns).uniq
    self
  end

  def save
    super
  end

end
