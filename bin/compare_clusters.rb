#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "utils/ppnum"
require "zinzout"
require "cluster_overlap"
require "cluster"

require "rspec"
require "rspec/expectations"
require "rspec/matchers"

include RSpec::Matchers

Services.mongo!

def overlap_line(overlap_hash)
  [overlap_hash[:cluster_id],
   overlap_hash[:volume_id],
   overlap_hash[:member_id],
   overlap_hash[:copy_count],
   overlap_hash[:brt_count],
   overlap_hash[:wd_count],
   overlap_hash[:lm_count],
   overlap_hash[:access_count]].join("\t")
end

if __FILE__ == $PROGRAM_NAME
  logger = Services.logger

  ARGF.each_line do |line|
    item_id = line.strip

    #
    cluster = Cluster.where("ht_items.item_id": item_id).first

    new_htitems = cluster.ht_items.map(&:item_id).sort

    new_holdings = {}
    ClusterOverlap.new(Cluster.where("ht_items.item_id": item_id).first).each do |o|
      if o.ht_item.item_id == item_id
        new_holdings[o.org] = o.to_hash.reject { |k,_| k == :cluster_id }
      end
    end

    #
    holdings_db = Services.holdings_db

    old_htitems = holdings_db["SELECT hhj2.volume_id from holdings_cluster_htitem_jn hhj1 join holdings_cluster_htitem_jn hhj2 on hhj1.cluster_id = hhj2.cluster_id and hhj1.volume_id = ?",item_id].map { |r| r[:volume_id] }.sort

    old_holdings = holdings_db[:holdings_htitem_htmember]
      .where(volume_id: item_id)
      .to_h { |h| [h[:member_id], h] }

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

end
