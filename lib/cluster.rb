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
  # store_in collection: "clusters"

  # # Cluster level stuff:
  # field :ocns
  # field :last_modified, type: DateTime
  # index({ocns: 1}, unique: true, partial_filter_expression: {ocns: {:$gt => 0}})
  # index({last_modified: 1})
  # scope :for_ocns, ->(ocns) { where(:ocns.in => ocns) }

  # # Holdings level stuff:
  # embeds_many :holdings, class_name: "Clusterable::Holding"

  # # HtItems level stuff:
  # embeds_many :ht_items, class_name: "Clusterable::HtItem"
  # index({"ht_items.item_id": 1}, unique: true, sparse: true)
  # scope :with_ht_item, ->(ht_item) { where("ht_items.item_id": ht_item.item_id) }

  # # OCNResolution level stuff:
  # embeds_many :ocn_resolutions, class_name: "Clusterable::OCNResolution"
  # index({"ocn_resolutions.ocns": 1}, unique: true, sparse: true)
  # scope :for_resolution, lambda { |resolution|
  #   where(:ocns.in => [resolution.deprecated, resolution.resolved])
  # }

  # # Commitments level stuff:
  # embeds_many :commitments, class_name: "Clusterable::Commitment"
  # index({"commitments.phase": 1}, unique: false, sparse: true) # keep
  # index({"commitments.committed_date": 1}, unique: false, sparse: true) # discard once phase is set

  # # Hooks:
  # before_save { |c| c.last_modified = Time.now.utc }

  # validates_each :ocns do |record, attr, value|
  #   value.each do |ocn|
  #     record.errors.add attr, "must be an integer" \
  #       unless (ocn.to_i if /\A[+-]?\d+\Z/.match?(ocn.to_s))
  #   end
  #   # ocns are a superset of ht_items.ocns
  #   record.errors.add attr, "must contain all ocns" \
  #     if (record.ht_items.collect(&:ocns).flatten +
  #         record.ocn_resolutions.collect(&:ocns).flatten - value).any?
  # end

  # # returns the first matching ht item by item id in this cluster, if any
  # #
  # # @param the item id to find
  # def ht_item(item_id)
  #   ht_items.to_a.find { |h| h.item_id == item_id }
  # end

  UPDATE_LAST_MODIFIED = {"$currentDate" => {last_modified: true}}.freeze
  def add_holdings(*items)
    push_to_field(:holdings, items.flatten, UPDATE_LAST_MODIFIED)
  end

  def add_ht_items(*items)
    push_to_field(:ht_items, items.flatten, UPDATE_LAST_MODIFIED)
  end

  def add_ocn_resolutions(*items)
    push_to_field(:ocn_resolutions, items.flatten, UPDATE_LAST_MODIFIED)
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
    @item_enums ||= ht_items.pluck(:n_enum).uniq
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
    relations.values.map(&:name).each do |relation|
      push_to_field(relation, cluster.send(relation).map(&:dup))
    end
  end

  def empty?
    ht_items.empty? && ocn_resolutions.empty? && holdings.empty? && commitments.empty?
  end

  def update_ocns
    self.ocns = [ocn_resolutions.pluck(:ocns) + ht_items.pluck(:ocns)].flatten.uniq
    save
  end

  def clusterable_ocn_tuples
    @clusterable_ocn_tuples ||= ocn_resolutions.pluck(:ocns) + ht_items.pluck(:ocns) +
      holdings.pluck(:ocn) + commitments.pluck(:ocn)
  end
end
