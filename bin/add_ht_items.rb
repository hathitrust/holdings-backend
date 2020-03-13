#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster"
require "ht_item"
require "json"
require "optparse"

File.open(ARGV.shift) do |line|
  rec = HtItem.hathifile_to_record(line)
  Cluster.where(ocns: { "$in": rec.ocns })
  # todo: merge them? or should this taken care of in HtItem.add or somewhere else?
end
