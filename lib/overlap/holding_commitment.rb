# frozen_string_literal: true

require "cluster"
require "services"

Services.mongo!

module Overlap
  # Given an ocn, gets:
  # * non-deprecated commitments in the matching cluster
  # * holdings eligible for commitments in the matching cluster
  class HoldingCommitment
    def initialize(ocn)
      # For holding-commitment overlaps we only care about spm clusters with ht_items
      @cluster = Cluster
        .where(ocns: ocn, "ht_items.0": {"$exists": 1})
        .find { |c| c.format == "spm" }
    end

    # Restrict holdings to ones that are eligible for commitments.
    def eligible_holdings
      @eligible_holdings ||= @cluster&.holdings&.select do |x|
        eligible_holding?(x)
      end
      @eligible_holdings ||= []
    end

    # Restrict commitments to non-deprecated.
    def active_commitments
      @active_commitments ||= @cluster&.commitments&.reject(&:deprecated?)
      @active_commitments ||= []
    end

    private

    # For a holding to be considered for commitments, it must be:
    # a currently held single part monograph that isn't brittle.
    def eligible_holding?(hol)
      (hol.mono_multi_serial == "spm" || hol.mono_multi_serial == "mon") &&
        (hol.status.empty? || hol.status == "CH") &&
        hol.condition.empty?
    end
  end
end
