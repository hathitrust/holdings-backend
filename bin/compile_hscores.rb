#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "utils/waypoint"
require "utils/ppnum"
require "cluster"
require "ht_item_overlap"

Mongoid.load!("mongoid.yml", :development)

# Find ht items that match the given org or all
def matching_clusters(org = nil)
  if org.nil?
    Cluster.where("ht_items.0": { "$exists": 1 },
                  "ht_items.access": "deny")
  else
    Cluster.where("holdings.0": { "$exists": 1 },
                  "ht_items.0": { "$exists": 1 },
                  "ht_items.access": "deny",
                  "$or": [{ "holdings.organization": org },
                          { "ht_items.content_provider_code": org }])
  end
end

# Compile the totals
def compile_total_hscore(frequency)
  totals = Hash.new {|hash, key| hash[key] = 0.0 }
  frequency.each do |organization, h_scores|
    h_scores.each do |num_orgs, freq|
      totals[organization] += (1.0 / num_orgs * freq)
    end
  end
  totals
end

# Supports histogram reporting
# { org => { 1 org : count, 2 org : count }
frequency = Hash.new {|hash, key| hash[key] = Hash.new(0) }

if __FILE__ == $PROGRAM_NAME
  BATCH_SIZE = 10_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Logger.new(STDERR)
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

  org = ARGV.shift

  matching_clusters(org).each do |c|
    c.ht_items.each do |ht_item|
      next unless ht_item.access == "deny"

      waypoint.incr
      overlap = HtItemOverlap.new(ht_item)
      overlap.matching_orgs.each do |organization|
        frequency[organization][overlap.matching_orgs.count] += 1
      end
      waypoint.on_batch {|wp| logger.info wp.batch_line }
    end
  end
  logger.info waypoint.final_line
  if org.nil?
    puts compile_total_hscore(frequency).to_json
  else
    puts compile_total_hscore(frequency)[org].to_json
  end
end
