# frozen_string_literal: true

require "cluster"
require "calculate_format"
require "single_part_overlap"
require "multi_part_overlap"
require "serial_overlap"

# Collects overlap records for every ht_item in a cluster
class ClusterOverlap
  include Enumerable

  attr_accessor :orgs, :cluster

  def initialize(cluster, orgs = nil)
    @cluster = cluster
    @orgs = orgs.nil? ? @cluster.organizations_in_cluster : [orgs].flatten
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
    case @cluster.format
    when "ser"
      SerialOverlap.new(@cluster, org, ht_item)
    when "spm"
      SinglePartOverlap.new(@cluster, org, ht_item)
    when "mpm"
      MultiPartOverlap.new(@cluster, org, ht_item)
    when "ser/spm"
      SinglePartOverlap.new(@cluster, org, ht_item)
    end
  end

  def self.matching_clusters(org = nil)
    if org.nil?
      Cluster.where("ht_items.0": { "$exists": 1 })
    else
      Cluster.where("ht_items.0": { "$exists": 1 },
                "$or": [{ "holdings.organization": org },
                        { "ht_items.billing_entity": org }])
    end
  end

end
