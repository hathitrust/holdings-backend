# frozen_string_literal: true

require "cluster"
require "services"

Services.mongo!

module Overlap
  # Given an ocn, gets:
  # * commitments in the matching cluster
  # * holdings eligible for commitments in the matching cluster
  # * all matched up pairs of holdings-commitments from the above
  class HoldingCommitment
    attr_reader :holdings, :commitments

    def initialize(ocn)
      @holdings    = []
      @commitments = []

      # For holding-commitment overlaps we only care about spm clusters with ht_items
      Cluster.where(ocns: ocn, "ht_items.0": { "$exists": 1 }).each do |cluster|
        if cluster.format == "spm"
          @holdings    = filter_eligible(cluster.holdings)
          @commitments = cluster.commitments.sort_by(&:organization)
        end
      end
    end

    # How many distinct orgs have reported holdings for the given cluster?
    def holdings_h
      @holdings.pluck(:organization).uniq.count
    end

    # How many distinct orgs have reported commitments for the given cluster?
    def commitments_h
      @commitments.pluck(:organization).uniq.count
    end

    # Return only holdings that could have a commitment.
    def filter_eligible(holdings)
      holdings.select {|x| x.mono_multi_serial == "mono" && (x.status.empty? || x.status == "CH") }
        .sort_by(&:organization)
    end

    # Return all holdings that match a commitment.
    def holdings_matching_commitment(commitment, holdings)
      holdings.select do |hol|
        # This could be the place to dig for commitments that only partially match holdings,
        # e.g. same org & ocn but diff local_id,
        # or   same org & local_id but diff ocn
        hol.organization == commitment.organization &&
          hol.ocn        == commitment.ocn          &&
          hol.local_id   == commitment.local_id
      end
    end

    # Return matching pairs of [com, hol].
    def matched_pairs
      pairs = []

      # Should make for fewer round-trips.
      holdings_by_org = Hash.new([])
      @holdings.each do |h|
        holdings_by_org[h.organization] << h
      end

      @commitments.each do |com|
        holdings_matching_commitment(com, holdings_by_org[com.organization]).each do |hol|
          pairs << [com, hol]
        end
      end
      pairs
    end

  end
end
