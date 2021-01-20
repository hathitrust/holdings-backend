#!bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift "../../../lib"
require 'ht_item_loader'
require_relative "../../spec_helper"

HFileLine = Struct.new(:ht_item, :holdings, keyword_init: true) do
  def mms
    item_id = ht_item.item_id
    if item_id =~ /mono/
      'mono'
    elsif item_id =~ /mpm/
      'multi'
    else
      'serial'
    end
  end
end

class SmallData

  def self.load!
    hfile       = __dir__ + '/hathifile_small.tsv'
    loader      = HtItemLoader.new
    hfile_lines = File.open(hfile).map { |line| HFileLine.new(ht_item: loader.item_from_line(line), holdings: line.chomp.split("\t").last) }
    ht_items    = hfile_lines.map(&:ht_item)
    ht_items.each { |item| ClusterHtItem.new(item).cluster }

    hfile_lines.each do |hfl|
      item = hfl.ht_item
      hfl.holdings.split(",").each do |school|
        next unless %w[anu bu cmu].include?(school)
        ph = Holding.new(
          ocn:               item.ocns.first,
          organization:      school,
          local_id:          "junk",
          mono_multi_serial: hfl.mms,
          date_received:     Date.today,
          n_enum:            item.enum_chron.split(",").first,
          n_chron:           item.enum_chron.split(",").last,
          uuid:              SecureRandom.uuid
        )
        ClusterHolding.new(ph).cluster
      end
    end
  end
end

