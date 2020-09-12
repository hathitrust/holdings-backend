#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster_ht_item"
require "batch_cluster_ht_item"
require "ht_item"
require "ocn_resolution"
require "zinzout"
require "utils/ppnum"
require "utils/waypoint"

Mongoid.load!("mongoid.yml", ENV["MONGOID_ENV"] || :development)

# Convert a tsv line from the hathifile into a record like hash
#
# @param hathifile_line, a tsv line
def hathifile_to_record(hathifile_line)
  fields = hathifile_line.split(/\t/)
  {
    item_id:         fields[0],
    ocns:            fields[7].split(",").map(&:to_i),
    ht_bib_key:      fields[3].to_i,
    rights:          fields[2],
    access:          fields[1],
    bib_fmt:         fields[19],
    enum_chron:      fields[4],
    collection_code: fields[20]
  }
end

MAX_RETRIES = 5
BATCH_SIZE = 10_000
logger = Logger.new(STDOUT)
waypoint = Utils::Waypoint.new
STDIN.set_encoding "utf-8"
logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

clean = ARGV.include?("--clean")

if clean
  logger.info "Removing clusters first"
  Cluster.each(&:delete)
end

filename = ARGV[0]
logger.info "Updating HT Items."

def process_batch(ocns, batch, retries = 0)
  raise "Too many retries for #{h.item_id}" if retries > MAX_RETRIES

  begin
    c = ClusterHtItem.new(ocns).cluster(batch)
    c.upsert if c.changed?
  rescue Mongo::Error::OperationFailure => e
    if /duplicate key error/.match?(e.code_name)
      puts "Got DuplicateKeyError while processing #{ocns}, retrying #{retries+1}"
      process_batch(ocns, batch, retries+1)
    end
  rescue ClusterError => e
    puts "Got ClusterError while processing #{ocns}, retrying #{retries+1}"
    process_batch(ocns, batch, retries+1)
  end
end

last_ocns = nil
batch = []

Zinzout.zin(filename).each do |line|
  waypoint.incr

  htitem = HtItem.new(hathifile_to_record(line))

  # always process htitems with no OCN as a batch of 1
  if last_ocns && (last_ocns.empty? || htitem.ocns != last_ocns)
    process_batch(last_ocns, batch)
    batch = []
  end

  batch << htitem
  last_ocns = htitem.ocns

  waypoint.on_batch {|wp| logger.info wp.batch_line }
end

# process final batch
process_batch(last_ocns, batch)

logger.info waypoint.final_line
