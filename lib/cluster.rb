# frozen_string_literal: true

# A set of identifiers (e.g. OCLC numbers) with a single "primary" identifier
class Cluster
  attr_reader :id, :members

  extend Forwardable

  def_delegators :members, :include?, :to_a, :each

  # Creates a new cluster from a hash (or MongoDB document)
  #
  # @param hash The hash or document from which to create the cluster.
  #    It should have an _id and members key.
  def self.from_hash(hash)
    new(*hash[:members])
  end

  # Create a new cluster.
  #
  # @param members An array of identifiers that belong in this cluster.
  def initialize(*members)
    @members = Set.new(members)
  end

  # Adds the given identifier to this cluster.
  #
  # @param id The identifier to add as a member of this cluster
  # @return This cluster
  def add(id)
    members.add(id)
    self
  end

  # Adds the members of the given cluster to this cluster.
  #
  # @param other The cluster whose members to merge with this cluster.
  # @return This cluster
  def merge(other)
    members.merge(other.members)
    self
  end

  # Serialize this cluster to a hash suitable for conversion to JSON etc
  def to_hash
    { members: members.to_a }
  end

end
