# frozen_string_literal: true

# A set of identifiers (e.g. OCLC numbers) with a single "primary" identifier.
class Cluster
  attr_reader :id, :members

  extend Forwardable

  def_delegators :members, :include?, :to_a, :each

  # Create a new cluster.
  #
  # @param id The primary identifier for the cluster
  #
  # @param members An array of identifiers that are equivalent to the primary
  # identifier
  #
  # @param members_set The backing store for this cluster, by default an
  # in-memory Set.
  def initialize(id, members = nil, members_set = Set.new(members))
    @id = id
    @members = members_set.add(id)
  end

  # Add an item to the cluster
  #
  # @param item The identifier to treat as equivalent to the primary identifier
  # for this cluster
  def add(item)
    members.add(item)
    self
  end

  # Merge two clusters together. All members in the other cluster will be added
  # to this cluster.
  #
  # @param other The cluster whose members to add to this cluster.
  def merge(other)
    members.merge(other.members)
    self
  end
end
