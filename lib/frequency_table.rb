# frozen_string_literal: true

require "json"

require "calculate_format"
require "overlap/ht_item_overlap"

class FrequencyTable
  def initialize
    @table = Hash.new do |hash, member|
      hash[member] = Hash.new { |fmt_hash, fmt| fmt_hash[fmt] = Hash.new(0) }
    end
  end

  def organizations
    @table.keys.sort
  end

  # Return {count1 => freq1, count2 => freq2, ...} for a given org and format
  def [](organization:, format:)
    @table[organization][format]
  end

  def add_ht_item(ht_item)
    item_format = CalculateFormat.new(ht_item.cluster).item_format(ht_item).to_sym
    item_overlap = Overlap::HtItemOverlap.new(ht_item)
    member_count = item_overlap.matching_members.count
    item_overlap.matching_members.each do |org|
      @table[org.to_sym][item_format][member_count] += 1
    end
  end

  def serialize
    [].tap do |data|
      @table.sort.each do |org, freq_data|
        data << [org, JSON.generate(freq_data)].join("\t")
      end
    end.join "\n"
  end
end
