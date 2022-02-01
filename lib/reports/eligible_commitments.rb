# frozen_string_literal: true

require "services"
require "overlap/holding_commitment"

module Reports
  # Given criteria, pull up all clusters that  match those criteria
  # AND have holdings,
  # AND have ht_items,
  # AND have no commitments,
  # AND are eligible for commitments.
  # Invoke via bin/reports/compile_eligible_commitments_report.rb
  class EligibleCommitments
    def header
      ["organization", "oclc_sym", "ocn", "local_id"]
    end

    def for_ocns(ocns = [])
      if ocns.empty?
        raise "No ocns given"
      end

      ocns.sort.uniq.each do |ocn|
        overlap = Overlap::HoldingCommitment.new(ocn)
        if overlap.active_commitments.empty?
          overlap.eligible_holdings.each do |h|
            yield [
              h.organization,
              Services.ht_organizations.members.fetch(h.organization)&.oclc_sym || "N/A",
              h.ocn,
              h.local_id
            ]
          end
        end
      end
    end

  end
end
