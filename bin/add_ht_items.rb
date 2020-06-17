#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster_ht_item"
require "ht_item"
require "ocn_resolution"
require "zinzout"
require "utils/ppnum"
require "utils/waypoint"

Mongoid.load!("mongoid.yml", :test)

# Convert a tsv line from the hathifile into a record like hash
#
# @param hathifile_line, a tsv line
def hathifile_to_record(hathifile_line)
  fields = hathifile_line.split(/\t/)
  { item_id:    fields[0],
    ocns:       fields[7].split(",").map(&:to_i),
    ht_bib_key: fields[3].to_i,
    rights:     fields[2],
    bib_fmt:    fields[19],
    enum_chron: fields[4] }
end

logger = Logger.new(STDOUT)
waypoint = Utils::Waypoint.new

BATCH_SIZE = 10_000

# rubocop:disable Layout/LineLength
logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"
# rubocop:enable Layout/LineLength

count = 0
update = ARGV[0] == "-u"
if update
  filename = ARGV[1]
  logger.info "Updating HT Items."
else
  filename = ARGV[0]
  logger.info "Adding HT Items."
end

Zinzout.zin(filename).each do |line|
  count += 1
  rec = hathifile_to_record(line)
  h = HtItem.new(rec)

  c = if update
    ClusterHtItem.new(h).update
  else
    ClusterHtItem.new(h).cluster
  end
  c.save!

  if (count % BATCH_SIZE).zero? && !count.zero?
    waypoint.mark(count)
    logger.info waypoint.batch_line
  end
end

waypoint.mark(count)
logger.info waypoint.final_line
