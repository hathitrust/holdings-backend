# frozen_string_literal: true

require "clusterable/holding"
require "clusterable/ht_item"
require "clusterable/commitment"
require "clusterable/ocn_resolution"
require "calculate_format"
require "cluster_error"

# A set of identifiers (e.g. OCLC numbers),
# - ocns
# - holdings
# - htitems
# - commitments
class Cluster
  attr_reader :ocns
  # can use if deserializing
  attr_writer :ht_items, :holdings

  def self.for_ocns(ocns)
    Services.logger.debug("Getting cluster for ocns #{ocns} from mariadb")
    # TODO: likely more efficient to get this from solr rather than from
    # mariadb - we can gather up everything in "oclc_search" from records with
    # matching OCNs

    # 1. Get all variant & canonical OCNs for the given OCNs
    concordanced_ocns = Clusterable::OCNResolution.concordanced_ocns(ocns)

    # 2. Get all catalog records matching those OCNs
    catalog_record_ocns = Clusterable::HtItem.related_ocns(concordanced_ocns)

    # 3. Get all variant & canonical OCNs from the expanded set above
    concordanced_catalog_ocns = Clusterable::OCNResolution.concordanced_ocns(catalog_record_ocns)

    new(ocns: concordanced_catalog_ocns)
  end

  def initialize(ocns: [])
    @ocns = ocns.map(&:to_i).to_set
  end

  # Call to ensure we don't load any of these things from the database
  def no_db_load!
    @ht_items ||= []
    @holdings ||= []
    @ocn_resolutions ||= []
  end

  def ocns=(ocns)
    @ocns = ocns.map(&:to_i).to_set
  end

  def ocn_resolutions
    @ocn_resolutions ||= Clusterable::OCNResolution.with_ocns(ocns, cluster: self).to_a
  end

  def ht_items
    @ht_items ||= Clusterable::HtItem.with_ocns(ocns, cluster: self).to_a
  end

  def ht_item(item_id)
    Clusterable::HtItem.find(item_id: item_id, ocns: ocns, cluster: self)
  end

  def commitments
    []
  end

  def holdings
    @holdings ||= Clusterable::Holding.with_ocns(ocns, cluster: self).to_a
  end

  def add_holding(holding)
    @holdings ||= []
    @holdings << holding
  end

  # invalidate memoized attributes after adding items elsewhere
  def invalidate_cache
    @holdings = nil
    @ocn_resolutions = nil
    @ht_items = nil
    @format = nil
    @organizations_in_cluster = nil
    @item_enums = nil
    @holding_enum_orgs = nil
    @org_enums = nil
    @organizations_with_holdings_but_no_matches = nil
    @copy_counts = nil
    @brt_counts = nil
    @wd_counts = nil
    @lm_counts = nil
    @holdings_by_org = nil
  end

  def format
    @format ||= CalculateFormat.new(self).cluster_format
  end

  def organizations_in_cluster
    @organizations_in_cluster ||= (holdings.map(&:organization) +
                                  ht_items.map(&:billing_entity)).uniq
  end

  def item_enums
    @item_enums ||= ht_items.map(&:n_enum).uniq
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

  def current_holding_counts
    @ch_counts ||= holdings_by_org
      .transform_values do
        |hs| hs.select do |holding| 
          # holding is assumed current if status is nil
          holding.status == "CH" || holding.status.nil?
        end.size
      end
    @ch_counts.default = 0
    @ch_counts
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

  def empty?
    ht_items.empty? && ocn_resolutions.empty? && holdings.empty? && commitments.empty?
  end
end
