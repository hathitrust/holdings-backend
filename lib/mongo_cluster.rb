# frozen_string_literal: true

require "services"

# A set of identifiers (e.g. OCLC numbers) with a single "primary" identifier,
# suitable for serializing & deserializing from MongoDB
class MongoCluster < Cluster
  attr_accessor :_id

  # Finds an existing cluster by id
  #
  # @param id The identifier to find
  #
  # @return a Cluster if the given id is a member of some cluster, or nil if it
  # is not
  def self.find_by_member(id)
    if (existing = collection.find(members: id.to_i).first)
      from_hash(existing)
    end
  end

  def self.find(id)
    find_by_member(id)
  end

  # Creates a new cluster from a hash (or MongoDB document)
  #
  # @param hash The hash or document from which to create the cluster.
  #    It should have an _id and members key.
  def self.from_hash(hash)
    new(*hash[:members], _id: hash[:_id])
  end

  #
  # Saves a cluster to persistent storage
  #
  # @param cluster The Cluster to save
  # @return This cluster
  def save
    collection.replace_one({ _id: _id }, to_hash, upsert: true)
    self
  end

  #
  # Deletes the given cluster
  #
  # @param id The ID to delete
  def delete
    collection.delete_one(_id: _id)
  end

  # Create a new cluster.
  #
  # @param _id: The MongoDB object ID for the object; auto-generated if not
  # provided

  # rubocop:disable Lint/UnderscorePrefixedVariableName
  # mongodb internally calls its object id field _id, so we should call it that
  # too..
  def initialize(*members, _id: BSON::ObjectId.new)
    super(*members)
    @_id = _id
  end
  # rubocop:enable Lint/UnderscorePrefixedVariableName

  # Serialize this cluster to a hash suitable for conversion to BSON etc
  def to_hash
    { _id: _id, members: members.map(&:to_i) }
  end

  def self.collection
    Services.cluster_collection
  end

  private

  def collection
    self.class.collection
  end
end
