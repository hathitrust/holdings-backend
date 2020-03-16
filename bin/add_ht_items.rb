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
  HtItem.add(rec)
end
