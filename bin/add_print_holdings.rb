#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster_holding"
require 'ocn_resolution'
require "holding"
require 'utils/waypoint'
require 'utils/ppnum'
require 'zinzout'


Mongoid.load!("mongoid.yml", :test)

BATCH_SIZE=100

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

waypoint = Utils::Waypoint.new
logger = Logger.new(STDOUT)

# rubocop:disable Layout/LineLength
logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"
# rubocop:enable Layout/LineLength

count = 0
Zinzout.zin(ARGV.shift).each do |line|
  next if /^OCN\tBIB/.match?(line)

  count += 1
  rec = holding_to_record(line.chomp)
  h = Holding.new(rec)
  c = ClusterHolding.new(h).cluster
  c.save

  if (count % BATCH_SIZE).zero? && !count.zero?
    waypoint.mark(count)
    logger.info waypoint.batch_line
  end
end

waypoint.mark(count)
logger.info waypoint.final_line
