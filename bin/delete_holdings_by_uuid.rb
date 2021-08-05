# frozen_string_literal: true

require "services"
require "holding"
require "cluster"
require "utils/waypoint"

DIGIT_RX = /\d/.freeze
UUID_RX  = /^[0-9a-f\-]+$/.freeze

Services.mongo!

# Takes path(s) to file(s) with lines of:
# ocn \t org \t holdings.uuid
# and delete matching holdings
#
# Usage: bundle exec ruby bin/delete_holdings_by_uuid.rb file_with_holdings.tsv

org_counts = {}

ARGV.each do |path|
  waypoint = Utils::Waypoint.new(1000)
  inf = File.open(path, "r")
  inf.each_line do |line|
    waypoint.incr
    waypoint.on_batch do |wp|
      puts wp.batch_line
    end

    (c_ocns, org, h_uuid) = line.strip.split("\t")

    next if c_ocns.nil?
    next if h_uuid.nil?
    next unless DIGIT_RX.match?(c_ocns)
    next unless UUID_RX.match?(h_uuid)

    Cluster.collection.update_one({ 'ocns' => c_ocns.to_i }, { '$pull' => { 'holdings' => { '$and' => [ { 'organization' => org }, { 'uuid' => h_uuid } ] } } } )
  end
  inf.close
  puts waypoint.final_line
end
