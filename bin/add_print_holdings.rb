#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster_holding"
require "holding"
require "pp"

Mongoid.load!("mongoid.yml", :test)

# Convert a tsv line from a validated holding file into a record like hash
#
# @param holding_line, a tsv line
def holding_to_record(holding_line)
  # OCN  BIB  MEMBER_ID  STATUS  CONDITION  DATE  ENUM_CHRON  TYPE  ISSN  N_ENUM  N_CHRON  GOV_DOC
  fields = holding_line.split(/\t/)
  { ocn:               fields[0].to_i,
    organization:      fields[2],
    local_id:          fields[1],
    enum_chron:        fields[6],
    status:            fields[3],
    condition:         fields[4],
    gov_doc_flag:      !fields[10].to_i.zero?,
    mono_multi_serial: fields[7],
    date_received:     DateTime.parse(fields[5]) }
end

File.open(ARGV.shift).each do |line|
  next if /^OCN\tBIB/.match?(line)

  rec = holding_to_record(line.chomp)
  h = Holding.new(rec)
  c = ClusterHolding.new(h).cluster
  c.save
end
