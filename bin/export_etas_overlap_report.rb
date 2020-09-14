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

Mongoid.load!("mongoid.yml", :development)

# Find clusters that match the given org
def matching_clusters(org = nil)
  if org.nil?
    Cluster.where("ht_items.0": { "$exists": 1 },
                  "holdings.0": { "$exists": 1 })
  else
    Cluster.where("ht_items.0": { "$exists": 1 },
                  "holdings.organization": org)
  end
end

def open_report(org, date, path)
  File.open("#{path}/#{org}_#{date}.tsv", "w")
end

if __FILE__ == $PROGRAM_NAME
  date_of_report = Time.now.strftime("%Y-%m-%d")
  report_path = ENV["path_to_etas_overlap_reports"]
  Dir.mkdir(report_path) unless File.exist?(report_path)
  reports = {}

  BATCH_SIZE = 10_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Logger.new(STDERR)
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

  org = ARGV.shift
  matching_clusters(org).each do |c|
    ClusterOverlap.new(c, org).each do |overlap|
      waypoint.incr
      overlap.matching_holdings.each do |holding|
        unless reports.key?(holding[:organization])
          reports[holding[:organization]] = open_report(holding[:organization],
                                                        date_of_report,
                                                        report_path)
        end
        reports[holding[:organization]].puts [holding[:ocn],
                                              holding[:local_id],
                                              CalculateFormat.new(c).cluster_format,
                                              overlap.ht_item.access,
                                              overlap.ht_item.rights].join("\t")
      end
      waypoint.on_batch {|wp| logger.info wp.batch_line }
    end
  end
  logger.info waypoint.final_line
end
