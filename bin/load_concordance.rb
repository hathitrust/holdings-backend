#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "oclc_number"
require "cluster_mapper"
require "mongo_cluster"

mapper = ClusterMapper.new(MongoCluster)
count = 0

STDIN.each_line do |line|
  (ocn, resolved_ocn) = line.split.map {|ocn| OCLCNumber.new(ocn.to_i) }

  # this will add ocn to the cluster containing resolved_ocn if it already
  # exists the other order would look up the unresolved ocn first and
  # potentially do an extra merge & delete
  mapper.add(resolved_ocn, ocn)

  count += 1

  if (count % 10_000).zero?
    puts "#{Time.now}: #{count} records loaded"
  end
end
