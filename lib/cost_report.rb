# frozen_string_literal: true

require "ht_item_overlap"

# Generates reports based on h_share
class CostReport
  attr_accessor :organization, :freq_table

  def initialize(org = nil)
    @organization = org
    # { org => { 1 org : count, 2 org : count }
    @freq_table = Hash.new {|hash, key| hash[key] = Hash.new(0) }
  end

  def matching_clusters
    if @organization.nil?
      Cluster.where("ht_items.0": { "$exists": 1 },
                "ht_items.access": "deny")
    else
      Cluster.where("ht_items.0": { "$exists": 1 },
                  "ht_items.access": "deny",
                  "$or": [{ "holdings.organization": @organization },
                          { "ht_items.billing_entity": @organization }])
    end
  end

  def add_ht_item_to_freq_table(ht_item)
    overlap = HtItemOverlap.new(ht_item)
    overlap.matching_orgs.each do |organization|
      @freq_table[organization.to_sym][overlap.matching_orgs.count] += 1
    end
  end

  def total_hscore
    return @total_hscore unless @total_hscore.nil?

    @total_hscore = Hash.new {|hash, key| hash[key] = 0.0 }
    @freq_table.each do |org, h_scores|
      h_scores.each do |num_orgs, freq|
        @total_hscore[org.to_sym] += (1.0 /num_orgs * freq)
      end
    end
    @total_hscore
  end

end
