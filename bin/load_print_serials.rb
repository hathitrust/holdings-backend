# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster_serial"
require "cluster"
require "pp"
require "utils/waypoint"
require "utils/ppnum"
require "zinzout"

Mongoid.load!("mongoid.yml", :test)

# Convert a tsv line from the print_serials_*.tsv into a hash
#
# @param line, a tsv line
def print_serial_to_record(line)
  id, ocns, issns, locations = line.chomp.split("\t")
  { record_id: id.to_i,
    ocns:      extract_ocns(ocns),
    issns:     extract_issns(issns),
    locations: locations }
end

# Extract ISSNs from issn field
def extract_issns(i_field)
  i_field.split(" | ")
end

# Extract OCNs from OCNs field
def extract_ocns(o_field)
  o_field.split(/(?: \| | )/).map {|o| o.gsub(/[^0-9]/, "").to_i }.uniq
end

BATCH_SIZE = 1_000
waypoint = Utils::Waypoint.new(BATCH_SIZE)
logger = Logger.new(STDOUT)

if __FILE__ == $PROGRAM_NAME
  # delete old print serial records
  Cluster.where("serials.0": { "$exists": 1 }).each do |c|
    c.serials.each(&:remove)
  end

  # load new file
  Zinzout.zin(ARGV.shift).each do |line|
    waypoint.incr
    rec = print_serial_to_record(line)
    s = Serial.new(rec)
    begin
      c = ClusterSerial.new(s).cluster
      c&.save
    rescue StandardError
      PP.pp rec
    end

    waypoint.on_batch {|wp| logger.info wp.batch_line }
  end

  logger.info waypoint.final_line
end
