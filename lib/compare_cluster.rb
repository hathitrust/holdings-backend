# frozen_string_literal: true

require "cluster"
require "cluster_overlap"

require "rspec"
require "rspec/expectations"
require "rspec/matchers"

# Compares htitems and holdings in the cluster for a given htitem with what is
# in mongodb and what is in the production holdings mysql tables
class CompareCluster
  include RSpec::Matchers

  attr_reader :item_id, :cluster

  def initialize(item_id)
    @item_id = item_id
    @cluster = Cluster.where("ht_items.item_id": item_id).first
  end

  def compare
    begin
      result = true
      expect(new_htitems).to match_array(old_htitems)
      expect(new_holdings.keys).to match_array(old_holdings.keys)
      expect(new_holdings).to eq(old_holdings)
    rescue RSpec::Expectations::ExpectationNotMetError => e
      puts e.inspect
      result = false
    end

    puts "Result for comparing cluster & holdings for #{item_id}: #{result}"
  end

  private

  def new_holdings
    @new_holdings ||= ClusterOverlap.new(cluster)
      .select {|o| o.ht_item.item_id == item_id }
      .to_h {|o| [o.org, o.to_hash.reject {|k, _| k == :cluster_id }] }
  end

  def old_holdings
    @old_holdings ||= Services.holdings_db[:holdings_htitem_htmember]
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
