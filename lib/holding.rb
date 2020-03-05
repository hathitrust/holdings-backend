# frozen_string_literal: true

require "mongoid"
require "set"

# A member holding
class Holding
  include Mongoid::Document

  # OCNS processed when performing updates
  @ocns_updated = Set.new

  field :ocn, type: Integer
  field :organization, type: String
  field :local_id, type: String
  field :enum_chron, type: String
  field :status, type: String
  field :condition, type: String
  field :gov_doc_flag, type: Boolean, default: false
  field :mono_multi_serial, type: String
  field :date_received, type: DateTime

  embedded_in :cluster

  validates_presence_of :ocn, :organization, :local_id, :mono_multi_serial
  validates :mono_multi_serial, inclusion: { in: ["mono", "multi", "serial"] }

  # Attach this embedded document to another parent
  #
  # @param new_parent, the parent cluster to attach to
  def move(new_parent)
    unless new_parent.id == _parent.id
      new_parent.holdings << dup
      delete
    end
  end

  # Add a new holding record, don't worry about updates,
  # e.g. full update of a member's records
  # Attach to first Cluster we find.
  #
  # @param holding_hash is a hash of values for a single holding
  def self.add(holding_hash)
    ocns = [holding_hash[:ocn]].flatten
    Cluster.where(ocns: { "$in": ocns }).each do |cluster|
      cluster.holdings.create(holding_hash)
      return cluster
    end

    # Not found, create a cluster
    cluster = Cluster.new(ocns: [ocns.first])
    cluster.save
    cluster.holdings.create(holding_hash)
    cluster
  end

  # Update holding records when we aren't sure which records to replace,
  # e.g. partial update of a member
  #
  # @param holding_hash is a hash of values for a single holding
  def self.update(holding_hash)
    # blow away the holdings for the cluster if we haven't seen the ocn
    unless ocns_updated.include? holding_hash[:ocn].to_i
      Cluster.where(ocns: holding_hash[:ocn]).each do |cluster|
        cluster.holdings.where(organization: holding_hash[:organization]).delete
        cluster.ocns.each {|o| @ocns_updated << o.to_i }
      end
    end
    add(holding_hash)
  end

  class << self
    attr_reader :ocns_updated
  end

  class << self
    attr_writer :ocns_updated
  end

  def ocns_updated
    self.class.ocns_updated
  end

end
