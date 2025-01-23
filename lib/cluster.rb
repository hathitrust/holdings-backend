# frozen_string_literal: true

require "clusterable/holding"
require "clusterable/ht_item"
require "clusterable/commitment"
require "clusterable/ocn_resolution"
require "calculate_format"
require "clustering/cluster_ht_item"
require "cluster_error"

# A set of identifiers (e.g. OCLC numbers),
# - ocns
# - holdings
# - htitems
# - commitments
class Cluster
  attr_reader :id, :ocns

  # make these available as instance methods
  extend Forwardable
  def_delegators self, :db, :table

  def self.db
    Services.holdings_db
  end

  def self.table
    db[:cluster_ocns]
  end

  # Creates a new cluster with the given OCNs, using the next value from the
  # cluster_ids sequence as the next primary key.
  #
  # We do not yet have a
  # cluster-specific table with a primary key; otherwise we'd do an insert
  # there. We may find we want that if we want to track cluster-specific info
  # such as modification date.
  def self.create(ocns: [])
    new(ocns: ocns).save
  end

  def self.first
    first_cluster_id = table.select(:cluster_id).first[:cluster_id]
    find(id: first_cluster_id)
  end

  def self.count
    table.distinct(:cluster_id).count
  end

  def self.find(id:)
    ocns = table.select(:ocn).where(cluster_id: id).map(:ocn)
    new(id: id, ocns: ocns)
  end

  def self.for_ocns(ocns)
    return to_enum(__method__, ocns) unless block_given?

    dataset = table
      .select(:cluster_id)
      .distinct
      .where(ocn: ocns)

    dataset.each do |row|
      yield find(id: row[:cluster_id])
    end
  end

  def self.each
    return to_enum(__method__) unless block_given?
    # TODO -- if we have a cluster table w/ last modified date and a primary
    # key, iterate over that instead
    dataset = table.select(:cluster_id).distinct

    dataset.each do |row|
      yield(find(id: row[:id]))
    end
  end

  def initialize(id: nil, ocns: [])
    @id = id
    @ocns = ocns.to_set
  end

  def ocns=(ocns)
    @ocns = ocns.to_set
  end

  def ocn_resolutions
    Clusterable::OCNResolution.with_ocns(ocns)
  end

  def ht_items
    Clusterable::HtItem.with_ocns(ocns)
  end

  def ht_item(item_id)
    Clusterable::HtItem.find(item_id: item_id, ocns: ocns)
  end

  def commitments
    []
  end

  def holdings
    Clusterable::Holding.with_ocns(ocns)
  end

  UPDATE_LAST_MODIFIED = {"$currentDate" => {last_modified: true}}.freeze
  def add_holdings(*items)
    push_to_field(:holdings, items.flatten, UPDATE_LAST_MODIFIED)
  end

  def add_ht_items(*items)
    push_to_field(:ht_items, items.flatten, UPDATE_LAST_MODIFIED)
  end

  # Add a Set of new OCLC numbers to this cluster.
  #
  # Raises a duplicate key error if these OCLC numbers are already in some other
  # cluster.
  def add_ocns(ocns)
    new_ocns = ocns - @ocns
    raise "cluster must be saved first" unless @id
    db.transaction do
      data = ocns.map { |ocn| [@id, ocn] }
      table.import([:cluster_id, :ocn], data)
      db.after_commit { @ocns.merge(new_ocns) }
    end
  end

  # Moves OCLC numbers from other clusters into this one.
  def update_ocns(ocns)
    new_ocns = ocns - @ocns
    return if new_ocns.empty?
    raise "cluster must be saved first" unless @id
    db.transaction do
      updated_rows = table.where(ocn: new_ocns.to_a).update(cluster_id: @id)
      if updated_rows != new_ocns.count
        raise "didn't update as many rows (#{updated_rows}) as expected (#{new_ocns.count})"
      end
      db.after_commit { @ocns.merge(new_ocns) }
    end
  end

  def add_commitments(*items)
    push_to_field(:commitments, items.flatten)
  end

  def format
    @format ||= CalculateFormat.new(self).cluster_format
  end

  def organizations_in_cluster
    @organizations_in_cluster ||= (holdings.pluck(:organization) +
                                  ht_items.pluck(:billing_entity)).uniq
  end

  def item_enums
    @item_enums ||= ht_items.collect(&:n_enum).uniq
  end

  # Maps enums to list of orgs that have a holding with that enum
  def holding_enum_orgs
    @holding_enum_orgs ||= holdings.group_by(&:n_enum)
      .transform_values { |holdings| holdings.map(&:organization) }
      .tap { |h| h.default = [] }
    @holding_enum_orgs
  end

  def org_enums
    @org_enums ||= holdings.group_by(&:organization)
      .transform_values { |holdings| holdings.map(&:n_enum) }
      .tap { |h| h.default = [] }
  end

  # Orgs that don't have "" enum chron or an enum chron found in the items
  def organizations_with_holdings_but_no_matches
    @organizations_with_holdings_but_no_matches ||= org_enums.reject do |_org, enums|
      enums.include?(" ") || (enums & item_enums).any?
    end.keys
  end

  # These counts will be incorrect if set prior to holdings/ht_items changes
  def copy_counts
    @copy_counts ||= holdings.group_by(&:organization).transform_values(&:size)
    @copy_counts.default = 0
    @copy_counts
  end

  def brt_counts
    @brt_counts ||= holdings_by_org
      .transform_values { |hs| hs.select { |holding| holding.condition == "BRT" }.size }
    @brt_counts.default = 0
    @brt_counts
  end

  def wd_counts
    @wd_counts ||= holdings_by_org
      .transform_values { |hs| hs.select { |holding| holding.status == "WD" }.size }
    @wd_counts.default = 0
    @wd_counts
  end

  def lm_counts
    @lm_counts ||= holdings_by_org
      .transform_values { |hs| hs.select { |holding| holding.status == "LM" }.size }
    @lm_counts.default = 0
    @lm_counts
  end

  def access_counts
    @access_counts ||= holdings_by_org
      .transform_values { |hs| hs.select(&:brt_lm_access?).size }
    @access_counts.default = 0
    @access_counts
  end

  def holdings_by_org
    @holdings_by_org ||= holdings.group_by(&:organization)
  end

  def push_to_field(field, items, extra_ops = {})
    raise "not implemented"
    return if items.empty?

    result = collection.update_one(
      {_id: _id},
      {"$push" => {field => {"$each" => items.map(&:as_document)}}}.merge(extra_ops),
      session: Mongoid::Threaded.get_session
    )
    raise ClusterError, "#{inspect} deleted before update" unless result.modified_count > 0

    items.each do |item|
      item.parentize(self)
      item._association = send(field)._association
      item.cluster = self
    end
    reload
  end

  def add_members_from(cluster)
    raise "not implemented"
    relations.values.map(&:name).each do |relation|
      push_to_field(relation, cluster.send(relation).map(&:dup))
    end
  end

  def empty?
    ht_items.empty? && ocn_resolutions.empty? && holdings.empty? && commitments.empty?
  end

  def clusterable_ocn_tuples
    @clusterable_ocn_tuples ||= ocn_resolutions.pluck(:ocns) + ht_items.pluck(:ocns) +
      holdings.pluck(:ocn) + commitments.pluck(:ocn)
  end

  # Get an id if we don't already have one, then persist
  # this as the cluster for each of our OCNs.
  #
  # Raises an error if we already have an ID, or a duplicate key
  # exception if any of the OCNs is already in some other cluster.
  def save
    db.transaction do
      raise "Call #add_ocns or #update_ocns to update an existing cluster" if @id
      @id = db.fetch("select next value for cluster_ids").get
      data = ocns.map { |ocn| [@id, ocn] }
      table.import([:cluster_id, :ocn], data)
    end

    self
  end

  alias_method :save!, :save
end
