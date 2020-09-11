# frozen_string_literal: true

require "cluster"
require "calculate_format"
require "single_part_overlap"
require "multi_part_overlap"
require "serial_overlap"

# Collects overlap records for every ht_item in a cluster
class ClusterOverlap
  attr_accessor :orgs

  def initialize(cluster, orgs = nil)
    @cluster = cluster
    @orgs = orgs.nil? ? organizations_in_cluster : [orgs].flatten
  end

  def each
    return enum_for(:each) unless block_given?

    @cluster.ht_items.each do |ht_item|
      @orgs.each do |org|
        overlap = overlap_record(ht_item, org)
        if overlap.copy_count.nonzero?
          yield overlap
        end
      end
    end
  end

  def overlap_record(ht_item, org)
    if CalculateFormat.new(@cluster).cluster_format == "ser"
      SerialOverlap.new(@cluster, org, ht_item)
    elsif CalculateFormat.new(@cluster).cluster_format == "spm"
      SinglePartOverlap.new(@cluster, org, ht_item)
    elsif CalculateFormat.new(@cluster).cluster_format == "mpm"
      MultiPartOverlap.new(@cluster, org, ht_item)
    elsif CalculateFormat.new(@cluster).cluster_format == "ser/spm"
      SinglePartOverlap.new(@cluster, org, ht_item)
    end
  end

  def organizations_in_cluster
    (@cluster.holdings.pluck(:organization) +
 @cluster.ht_items.pluck(:billing_entity)).uniq
  end
end
