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
class OCNLessCluster
  attr_reader :id
  attr_writer :ht_items

  def initialize(bib_key:)
    @bib_key = bib_key
  end

  def ocns
    @ocns ||= Set.new.freeze
  end

  # Call to ensure we don't load ht items from the database
  def no_db_load!
    @ht_items ||= []
  end

  def ht_items
    @ht_items ||= Clusterable::HtItem.with_bib_key(@bib_key)
  end

  def commitments
    []
  end

  def holdings
    []
  end

  def format
    @format ||= CalculateFormat.new(self).cluster_format
  end

  def organizations_in_cluster
    @organizations_in_cluster ||= ht_items.collect(&:billing_entity).uniq
  end

  def item_enums
    @item_enums ||= ht_items.collect(&:n_enum).uniq
  end

  def holding_enum_orgs
    Hash.new { [] }
  end

  def org_enums
    Hash.new { [] }
  end

  # Orgs that don't have "" enum chron or an enum chron found in the items
  def organizations_with_holdings_but_no_matches
    []
  end

  def copy_counts
    Hash.new(0)
  end

  def brt_counts
    Hash.new(0)
  end

  def wd_counts
    Hash.new(0)
  end

  def lm_counts
    Hash.new(0)
  end

  def access_counts
    Hash.new(0)
  end

  def holdings_by_org
    {}
  end
end
