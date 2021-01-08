# frozen_string_literal: true

require "cluster"
require "cluster_overlap"

require "pp"

# Compares htitems and holdings in the cluster for a given htitem with what is
# in mongodb and what is in the production holdings mysql tables
class CompareCluster
  attr_reader :item_id, :cluster

  def initialize(item_id)
    @item_id = item_id
    @cluster = Cluster.where("ht_items.item_id": item_id).first
  end

  def compare
    puts "Comparing holdings for htitem #{item_id}; " \
      "cluster format: #{CalculateFormat.new(@cluster).cluster_format}"

    #compare_htitems
    compare_holdings_keys
    compare_holdings_values
  end

  private

  def dump_cluster_htitem_ocns(item_id)
    cluster = Cluster.where("ht_items.item_id": item_id).first
    pp(cluster.ht_items.select {|h| h.item_id == item_id })
    puts "Cluster OCNS: #{@cluster.ocns}"
  end

  def dump_cluster_holdings(org)
    pp(cluster.holdings.select {|h| h.organization == org })
  end

  def compare_htitems
    return if new_htitems != old_htitems

    new_not_old = new_htitems - old_htitems
    old_not_new = old_htitems - new_htitems

    new_not_old.each do |item_id|
      puts "In new system but not old system: #{item_id}"
      dump_cluster_htitem_ocns(item_id)
    end

    old_not_new.each do |item_id|
      puts "In old system but not new system: #{item_id}"
      dump_cluster_htitem_ocns(item_id)
    end
  end

  def compare_holdings_keys
    new_org = new_holdings.keys.sort
    old_org = old_holdings.keys.sort
    return if new_org == old_org

    new_not_old = new_org - old_org
    old_not_new = old_org - new_org

    puts "HTItem with mismatched holdings: "
    dump_cluster_htitem_ocns(item_id)

    new_not_old.each do |org|
      puts "New system has overlap holdings, old system doesn't for #{org}"
      puts "Holdings on cluster for #{org}:"
      dump_cluster_holdings(org)
    end

    old_not_new.each do |org|
      puts "Old system has overlap holdings, new system doesn't for #{org}"
      puts "Holdings on cluster for #{org}:"
      dump_cluster_holdings(org)
      puts "Old holdings for #{org}:"
      pp old_holdings[org]
    end
  end

  def compare_holdings_values
    return if new_holdings == old_holdings

    puts "Mismatched holdings values: "
    # keys should match
    new_holdings
      .reject {|org, holdings| holdings == old_holdings[org] }
      .each do |org, holdings|
        puts "New system holdings for #{org}"
        pp holdings

        puts "Old system holdings for #{org}"
        pp old_holdings[org]

        puts "Holdings on cluster for #{org}"
        dump_cluster_holdings(org)
      end
  end

  def new_holdings
    @new_holdings ||= ClusterOverlap.new(cluster)
      .select {|o| o.ht_item.item_id == item_id }
      .to_h {|o| [o.org, o.to_hash.reject {|k, _| k == :cluster_id }] }
  end

  def old_holdings
    @old_holdings ||= Services.holdings_db[:holdings_htitem_htmember_jn_oct]
      .where(volume_id: item_id)
      .to_h {|h| [h[:member_id], h] }
  end

  def new_htitems
    @new_htitems ||= cluster.ht_items.map(&:item_id).sort
  end

  def old_htitems
    @old_htitems ||=
      Services.holdings_db[<<~SQL, item_id]
        SELECT hhj2.volume_id
          FROM holdings_cluster_htitem_jn hhj1
          JOIN holdings_cluster_htitem_jn hhj2
            ON hhj1.cluster_id = hhj2.cluster_id
               AND hhj1.volume_id = ?
      SQL
        .map {|r| r[:volume_id] }.sort
  end
end
