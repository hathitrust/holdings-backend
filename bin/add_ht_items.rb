#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster_ht_item"
require "ht_item"

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

File.open(ARGV.shift, "r:UTF-8").each do |line|
  rec = hathifile_to_record(line)
  h = HtItem.new(rec)
  c = ClusterHtItem.new(h).cluster
  c.save
end
