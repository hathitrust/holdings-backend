# frozen_string_literal: true

require "mongoid"
require "holding"
require "ht_item"
require "commitment"
require "ocn_resolution"
require "calculate_format"
require "cluster_ht_item"
require "cluster_error"

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
  embeds_many :commitments
  index({ ocns: 1 },
        unique: true,
        partial_filter_expression: { ocns: { :$gt => 0 } })
  index({ "ht_items.item_id": 1 }, unique: true, sparse: true)
  index({ "ocn_resolutions.ocns": 1 }, unique: true, sparse: true)
  scope :for_resolution, lambda {|resolution|
    where(:ocns.in => [resolution.deprecated, resolution.resolved])
  }
  scope :for_ocns, ->(ocns) { where(:ocns.in => ocns) }
  scope :with_ht_item, ->(ht_item) { where("ht_items.item_id": ht_item.item_id) }

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
    Services.logger.debug "Deleted cluster #{other.inspect} (merged into #{inspect})"
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
  def self.merge_many(clusters)
    c = clusters.shift
    if clusters.any?
      raise ClusterError, "cluster disappeared, try again" if c.nil?

      Retryable.with_transaction { c.merge_many(clusters) }
    end
    c
  end

  # returns the first matching ht item by item id in this cluster, if any
  #
  # @param the item id to find
  def ht_item(item_id)
    ht_items.to_a.find {|h| h.item_id == item_id }
  end

  def add_holdings(*items)
    push_to_field(:holdings, items.flatten)
  end

  def add_ht_items(*items)
    push_to_field(:ht_items, items.flatten)
  end

  def add_ocn_resolutions(*items)
    push_to_field(:ocn_resolutions, items.flatten)
  end

  def add_ocns(*ocns_to_add)
    return if ocns_to_add.empty?

    result = collection.update_one(
      { _id: _id },
      { "$push" => { ocns: { "$each" => ocns_to_add.flatten } } },
      session: Mongoid::Threaded.get_session
    )
    raise ClusterError, "#{inspect} deleted before update" unless result.modified_count > 0
  end

  def format
    @format ||= CalculateFormat.new(self).cluster_format
  end

  def organizations_in_cluster
    @organizations_in_cluster ||= (holdings.pluck(:organization) +
                                  ht_items.pluck(:billing_entity)).uniq
  end

  def item_enum_chrons
    @item_enum_chrons ||= ht_items.pluck(:n_enum).uniq
  end

  # Maps enumchrons to list of orgs that have a holding with that enumchron
  def holding_enum_chron_orgs
    @holding_enum_chron_orgs ||= holdings.group_by(&:n_enum)
      .transform_values {|holdings| holdings.map(&:organization) }
      .tap {|h| h.default = [] }
    @holding_enum_chron_orgs
  end

  def org_enum_chrons
    @org_enum_chrons ||= holdings.group_by(&:organization)
      .transform_values {|holdings| holdings.map(&:n_enum) }
      .tap {|h| h.default = [] }
  end

  # Orgs that don't have "" enum chron or an enum chron found in the items
  def organizations_with_holdings_but_no_matches
    org_enum_chrons.reject do |_org, enums|
      enums.include?("") || (enums & item_enum_chrons).any?
    end.keys
  end

  def billing_entities
    @billing_entities ||= ht_items.pluck(:billing_entity).uniq
  end

  def push_to_field(field, items)
    return if items.empty?

    result = collection.update_one(
      { _id: _id },
      { "$push" => { field => { "$each" => items.map(&:as_document) } } },
      session: Mongoid::Threaded.get_session
    )
    raise ClusterError, "#{inspect} deleted before update" unless result.modified_count > 0

    items.each do |item|
      item.parentize(self)
      item._association = send(field)._association
      item.cluster=self
    end
    reload
  end

  def add_members_from(cluster)
    relations.values.map(&:name).each do |relation|
      push_to_field(relation, cluster.send(relation).map(&:dup))
    end
  end

end
