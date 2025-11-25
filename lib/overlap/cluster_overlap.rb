# frozen_string_literal: true

require "cluster"
require "calculate_format"
require "overlap/single_part_overlap"
require "overlap/multi_part_overlap"
require "overlap/serial_overlap"

module Overlap
  # Collects overlap records for every ht_item and organization in a cluster
  class ClusterOverlap
    include Enumerable

    attr_accessor :orgs, :cluster

    def initialize(cluster, orgs = nil)
      @cluster = cluster
      @orgs = orgs.nil? ? @cluster.organizations_in_cluster : [orgs].flatten
    end

    def each
      return enum_for(__method__) unless block_given?

      @cluster.ht_items.each do |ht_item|
        for_item(ht_item) { |overlap| yield overlap }
      end
    end

    def for_item(ht_item)
      return enum_for(__method__, ht_item) unless block_given?

      @orgs.each do |org|
        overlap = self.class.overlap_record(org, ht_item)
        if overlap.copy_count.nonzero?
          yield overlap
        end
      end
    end

    def self.overlap_record(org, ht_item)
      case ht_item.cluster.format
      when "ser"
        SerialOverlap.new(org, ht_item)
      when "spm"
        SinglePartOverlap.new(org, ht_item)
      when "mpm"
        MultiPartOverlap.new(org, ht_item)
      when "ser/spm"
        SinglePartOverlap.new(org, ht_item)
      end
    end
  end
end
