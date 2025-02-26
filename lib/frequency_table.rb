# frozen_string_literal: true

require "json"

require "calculate_format"
require "overlap/ht_item_overlap"

class FrequencyTable
  protected attr_reader :table

  def initialize(data: nil)
    @log = File.open("freqtable-debug-#{$$}.txt", "w")
    @table = case data
    when String
      JSON.parse(data, symbolize_names: true)
    when Hash
      deep_copy data
    when NilClass
      {}
    else
      raise "unrecognized data format #{data.inspect}"
    end
  end

  def to_json
    JSON.generate(table)
  end

  def ==(other)
    self.class == other.class && table == other.table
  end

  # returns data if it's there, but doesn't add empty hashes/zeroes as values
  # in the table
  def fetch(organization: nil, format: nil, bucket: nil)
    return table if organization.nil?

    data = table[organization.to_sym] || {}
    if format
      data = data[format.to_sym] || {}
      if bucket
        data = data[bucket.to_s.to_sym] || 0
      end
    end
    data
  end

  def each
    return to_enum(__method__) unless block_given?
    table.each do |key, value|
      yield key, value
    end
  end

  def +(other)
    new_obj = self.class.new
    new_obj.append! self
    new_obj.append! other
  end

  # We try to optimize this beyond a deep addition from the leaves inward by
  # checking for missing keys and when possible copying chunks of the operand's
  # data structure.
  # We use `Marshal` for deep copies and `clone` for shallow copies in order to keep
  # prevent subsequent changes to the addend from affecting this object.
  def append!(other)
    other.each do |org, data|
      # Example data: org = :umich, data = {:spm=>{1=>1}}
      if !table.key? org
        table[org] = deep_copy other.table[org]
        next
      end
      table[org] = {} unless table.key?(org)
      data.each do |fmt, frequencies|
        # Example data: fmt = :spm, frequencies = {1 => 1}
        #
        # Safe to shallow clone `frequencies` since its keys and values are scalars.
        if !table[org].key? fmt
          table[org][fmt] = frequencies.clone
          next
        end
        frequencies.each do |bucket, count|
          increment(organization: org, format: fmt, bucket: bucket, amount: count)
        end
      end
    end
    self
  end

  def add_ht_item(ht_item)
    item_format = CalculateFormat.new(ht_item.cluster).item_format(ht_item).to_sym
    item_overlap = Overlap::HtItemOverlap.new(ht_item)
    member_count = item_overlap.matching_members.count
    item_overlap.matching_members.each do |org|
      @log.puts "add_ht_item\t#{ht_item.item_id}\t#{org}\t#{item_format}\t#{member_count}"
      increment(organization: org, format: item_format, bucket: member_count)
    end
  end

  def increment(organization:, format:, bucket:, amount: 1)
    org = organization.to_sym
    fmt = format.to_sym
    bucket = bucket.to_s.to_sym
    table[org] = {} unless table.key?(org)
    table[org][fmt] = {} unless table[org].key?(fmt)
    table[org][fmt][bucket] = 0 unless table[org][fmt].key?(bucket)
    table[org][fmt][bucket] += amount
  end

  private

  def deep_copy(obj)
    Marshal.load(Marshal.dump(obj))
  end
end
