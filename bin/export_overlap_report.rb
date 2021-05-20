#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "ocn_resolution"
require "holding"
require "utils/waypoint"
require "utils/ppnum"
require "zinzout"
require "cluster_overlap"
require "pry"
require "pp"

Mongoid.load!("mongoid.yml", :test)

BATCH_SIZE = 10_000

def overlap_line(overlap_hash)
  [overlap_hash[:lock_id],
   overlap_hash[:cluster_id],
   overlap_hash[:volume_id],
   overlap_hash[:n_enum],
   overlap_hash[:member_id],
   overlap_hash[:copy_count],
   overlap_hash[:brt_count],
   overlap_hash[:wd_count],
   overlap_hash[:lm_count],
   overlap_hash[:access_count]].join("\t")
end

def report(org)
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Services.logger
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

  ClusterOverlap.matching_clusters(org).each do |c|
    ClusterOverlap.new(c, org).each do |overlap|
      waypoint.incr
      puts overlap_line(overlap.to_hash)
      waypoint.on_batch {|wp| logger.info wp.batch_line }
    end
  end
  logger.info waypoint.final_line
end

if __FILE__ == $PROGRAM_NAME
  require 'optparse'
  
  options = {}
  OptionParser.new do |opts|
    opts.on("-f", "--full",
      "Produce overlap records for all matching clusters. Default: Clusters modified in last 36 hours") do |f|
      options.full = f
    end
    opts.on("-o", "--organization", "Limit overlap records to a particular organization.") do |org|
      options.organization = org || ''
    end
  end

  org = ARGV.shift
  report(org)
end
