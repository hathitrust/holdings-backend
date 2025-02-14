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

  def [](organization)
    @table[organization.to_sym]
  end

  # For testing. I don't know if this is useful in the long run.
  def to_h
    @table.clone.freeze
  end

  # Lower-memory alternative to `to_h` for the purposes of `+` and `append!`
  def each
    @table.each do |key, value|
      yield key, value
    end
  end

  # Create a public #append(ft) method that we can call on a clone?
  def +(other)
    new_obj = self.class.new
    new_obj.append! self
    new_obj.append! other
  end

  # We try to optimize this beyond a deep addition from the leaves inward by
  # checking for missing keys and when possible copying chunks of the operand's
  # data structure.
  def append!(other)
    other.each do |org, data|
      # Example data: org = :umich, data = {:spm=>{1=>1}}
      #
      # One could try to optimize this level by detecting missing `org` keys
      # in the receiver and copying over an entire chunk of data structure from `other`
      # but subsequent changes to `self` can propagate to `other`.
      # `Marshal` can't handle the funky initializer on `@data`
      # ("can't dump hash with default proc") so that deep copy hack doesn't seem
      # available to us.
      data.each do |fmt, frequencies|
        # Example data: fmt = :spm, frequencies = {1 => 1}
        #
        # Safe to shallow clone `frequencies` since its keys and values are scalars.
        if !@table[org].key? fmt
          @table[org][fmt] = frequencies.clone
          next
        end
        frequencies.each do |bucket, count|
          @table[org][fmt][bucket] += count
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
