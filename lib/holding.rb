# frozen_string_literal: true

require "mongoid"
require "set"

# A member holding
# - ocns
# - organization
# - local_id
# - enum_chron
# - status
# - condition
# - gov_doc_flag
# - mono_multi_serial
# - date_received
class Holding
  include Mongoid::Document

  # OCNS processed when performing updates
  @ocns_updated = Set.new

  field :ocns, type: Array
  field :organization, type: String
  field :local_id, type: String
  field :enum_chron, type: String
  field :status, type: String
  field :condition, type: String
  field :gov_doc_flag, type: Boolean, default: false
  field :mono_multi_serial, type: String
  field :date_received, type: DateTime

  embedded_in :cluster

  validates_presence_of :ocns, :organization, :local_id, :mono_multi_serial
  validates :mono_multi_serial, inclusion: { in: ["mono", "multi", "serial"] }
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
    ocns = [holding_hash[:ocns]].flatten
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
    unless (ocns_updated & holding_hash[:ocns].map(&:to_i)).any?
      delete(holding_hash[:organization], holding_hash[:ocns])
        .each {|o| @ocns_updated << o.to_i }
    end
    add(holding_hash)
  end

  # Delete holding records when they match a member/ocn pair
  #
  # @param organization is the member organization
  # @param ocns is the ocns this applies to
  def self.delete(organization, ocns)
    ocns_found = []
    Cluster.where(ocns:
      { "$in": ocns.map(&:to_i) }).each do |cluster|
        cluster.holdings.where(organization: organization)
          .delete
        ocns_found << cluster.ocns
      end
    ocns_found.flatten.uniq
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

  def to_hash
    { ocns:              ocns,
      organization:      organization,
      local_id:          local_id,
      enum_chron:        enum_chron,
      status:            status,
      condition:         condition,
      gov_doc_flag:      gov_doc_flag,
      mono_multi_serial: mono_multi_serial,
      date_received:     date_received }
  end

end
