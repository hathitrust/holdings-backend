# frozen_string_literal: true

require "json"

require "calculate_format"
require "overlap/ht_item_overlap"

class FrequencyTable
  protected attr_reader :table

  def initialize(data: nil)
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

  def keys
    table.keys.sort
  end

  def frequencies(organization:, format:)
    return [] unless table.key? organization.to_sym

    [].tap do |freqs|
      table[organization.to_sym][format.to_sym]&.each do |bucket, frequency|
        freqs << Frequency.new(bucket: bucket, frequency: frequency)
      end
    end
  end

  def each
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
          table[org][fmt][bucket] += count
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
      increment(organization: org, format: item_format, bucket: member_count)
    end
  end

  def increment(organization:, format:, bucket:)
    org = organization.to_sym
    fmt = format.to_sym
    bucket = bucket.to_s.to_sym
    table[org] = {} unless table.key?(org)
    table[org][fmt] = {} unless table[org].key?(fmt)
    table[org][fmt][bucket] = 0 unless table[org][fmt].key?(bucket)
    table[org][fmt][bucket] += 1
  end

  private

  def deep_copy(obj)
    Marshal.load(Marshal.dump(obj))
  end
end

# Encapsulate a member count a.k.a. bucket and its corresponding frequency.
# Both are integers.
# This is an immutable "readout" class not used in the FrequencyTable internals
# (mainly so FrequencyTable JSON can use all native types).
class Frequency
  attr_accessor :bucket, :frequency

  # Bucket may be from serialized data with symbolized hash keys, so we take care
  # to turn it into an Integer.
  # (This initializer lets you get away with passing `bucket` as a lot of different
  # classes that cast to Integer via String; it's really only intended to be used with
  # Integer/Symbol/String, however.)
  def initialize(bucket:, frequency:)
    @bucket = if bucket.is_a?(Integer)
      bucket
    else
      bucket.to_s.to_i
    end
    if !frequency.is_a?(Integer)
      raise "frequency initialized with unknown class #{frequency.class}"
    end
    @frequency = frequency
  end

  def ==(other)
    self.class == other.class && bucket == other.bucket && frequency == other.frequency
  end

  def to_a
    [bucket, frequency]
  end

  def to_h
    {bucket: bucket, frequency: frequency}
  end

  alias_method :member_count, :bucket
end
