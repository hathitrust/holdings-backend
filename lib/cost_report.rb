# frozen_string_literal: true

require "ht_item_overlap"
require "utils/waypoint"
require "services"

# Generates reports based on h_share
class CostReport
  attr_accessor :organization, :logger, :maxlines, :target_cost

  def initialize(org = nil, cost: ENV["target_cost"], lines: 1_000_000, logger: Services.logger)
    @organization = org
    @target_cost = Float(cost)
    @maxlines = lines
    @logger = logger
    # Member Hash of a format hash of a member count hash
    # { org => { ser : { 1 org : count, 2 org : count }, mpm : {...
    @freq_table = Hash.new do |hash, member|
      hash[member] = Hash.new {|fmt_hash, fmt| fmt_hash[fmt] = Hash.new(0) }
    end
  end

  def num_volumes
    @num_volumes ||= Cluster.collection.aggregate(
      [
        { '$match': { "ht_items.0": { "$exists": 1 } } },
        { '$group': { _id: nil, items_count: { "$sum": { '$size': "$ht_items" } } } }
      ]
    ).first[:items_count]
  end

  def num_pd_volumes
    @num_pd_volumes ||= Cluster.collection.aggregate(
      [
        { '$match': { "ht_items.0": { "$exists": 1 } } },
        { '$group': { _id:         nil,
                      items_count: { "$sum": { "$size": {
                        "$filter": { input: "$ht_items",
                                     as:    "item",
                                     cond:  { "$eq": ["$$item.access", "allow"] } }
                      } } } } }
      ]
    ).first[:items_count]
  end

  def cost_per_volume
    target_cost / num_volumes.to_f
  end

  def total_weight
    Services.ht_members.members.map {|_id, member| member.weight }.sum
  end

  def pd_cost
    cost_per_volume * num_pd_volumes
  end

  def pd_cost_for_member(member)
    member_weight     = Services.ht_members[member.to_s].weight
    (pd_cost / total_weight) * member_weight
  end

  def freq_table
    compile_frequency_table unless @freq_table.any?
    @freq_table
  end

  def compile_frequency_table
    waypoint = Utils::Waypoint.new(maxlines)
    logger.info("Begin compiling hscore frequency table.")
    matching_clusters.each do |c|
      c.ht_items.each do |ht_item|
        next unless ht_item.access == "deny"

        waypoint.incr
        add_ht_item_to_freq_table(ht_item)
        waypoint.on_batch {|wp| logger.info wp.batch_line }
      end
    end
  end

  def add_ht_item_to_freq_table(ht_item)
    item_overlap = HtItemOverlap.new(ht_item)
    item_overlap.matching_orgs.each do |org|
      @freq_table[org.to_sym][ht_item._parent.format.to_sym][item_overlap.matching_orgs.count] += 1
    end
  end

  def matching_clusters
    if @organization.nil?
      Cluster.where("ht_items.0": { "$exists": 1 },
                "ht_items.access": "deny").no_timeout
    else
      Cluster.where("ht_items.0": { "$exists": 1 },
                  "ht_items.access": "deny",
                  "$or": [{ "holdings.organization": @organization },
                          { "ht_items.billing_entity": @organization }]).no_timeout
    end
  end

  def total_hscore(member)
    spm_total(member) + mpm_total(member) + ser_total(member)
  end

  [:spm, :ser, :mpm].each do |format|
    # HScore for a particular format
    define_method "#{format}_total".to_sym do |member|
      total = 0.0
      freq_table[member.to_sym][format].each do |num_orgs, freq|
        total += freq.to_f / num_orgs
      end
      total
    end

    # Costs for a particular format
    define_method "#{format}_costs".to_sym do |member|
      public_send("#{format}_total", member) * cost_per_volume
    end
  end

  def total_ic_costs(member)
    total_hscore(member) * cost_per_volume
  end

  def extra_per_member
    total_ic_costs(:hathitrust) / (Services.ht_members.members.keys - ["hathitrust"]).count
  end

  def total_cost_for_member(member)
    total_ic_costs(member) + pd_cost_for_member(member) + extra_per_member
  end

end
