#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "utils/waypoint"
require "utils/ppnum"
require "zinzout"
require "cluster_overlap"
require "etas_overlap"

Services.mongo!

def open_report(org, date, path)
  File.open("#{path}/#{org}_#{date}.tsv", "w")
end

if __FILE__ == $PROGRAM_NAME
  date_of_report = Time.now.strftime("%Y-%m-%d")
  report_path = Settings.etas_overlap_reports_path
  Dir.mkdir(report_path) unless File.exist?(report_path)
  reports = {}

  BATCH_SIZE = 10_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Logger.new($stderr)
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

  org = ARGV.shift
  ClusterOverlap.matching_clusters(org).each do |c|
    ClusterOverlap.new(c, org).each do |overlap|
      waypoint.incr
      overlap.matching_holdings.each do |holding|
        unless reports.key?(holding[:organization])
          reports[holding[:organization]] = open_report(holding[:organization],
                                                        date_of_report,
                                                        report_path)
        end
        etas_record = ETASOverlap.new(ocn: holding[:ocn],
                                      local_id: holding[:local_id],
                                      item_type: c.format,
                                      access: overlap.ht_item.access,
                                      rights: overlap.ht_item.rights)

        reports[holding[:organization]].puts etas_record
      end
      waypoint.on_batch {|wp| logger.info wp.batch_line }
    end
  end
  logger.info waypoint.final_line
end
