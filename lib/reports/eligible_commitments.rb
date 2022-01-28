# frozen_string_literal: true

require "services"
require "overlap/holding_commitment"

module Reports
  # Given criteria, pull up all holdings that match those criteria
  # AND are eligible for commitments AND have no commitments.
  # Invoke via bin/reports/compile_eligible_commitments_report.rb
  class EligibleCommitments
    def header
      [
        "organization",
        "oclc_sym",
        "ocn",
        "local_id"
      ]
    end

    # In order to get the commitments that could have holdings but don't,
    # get the holdings, the matched pairs, and remove from holdings the ones
    # that are in a matched pair
    def for_ocns(ocns = [])
      if ocns.empty?
        raise "No ocns given"
      end

      ocns.sort.uniq.each do |ocn|
        overlap = Overlap::HoldingCommitment.new(ocn)
        holdings = overlap.holdings
        # Matched pairs in a HoldingCommitment is [[com1, hol1], [com2, hol2], ...].
        overlap.matched_pairs.each do |pair|
          # Remove the matched hol from holdings ...
          holdings.delete(pair.last)
          puts "deleting a holding"
        end
        # ... and what you are left with are holdings without commitments.
        holdings.each do |h|
          yield [
            h.organization,
            organization_oclc_symbol(h.organization),
            h.ocn,
            h.local_id
          ]
        end
      end
    end

    def organization_oclc_symbol(org)
      @ht_organizations ||= Services.ht_organizations
      if @ht_organizations.members.key?(org)
        @ht_organizations.members[org].oclc_sym
      else
        "N/A"
      end
    end

    def we_have_seen?(id)
      @seen ||= {}
      @seen.key?(id) || !(@seen[id] = true)
    end

  end
end
