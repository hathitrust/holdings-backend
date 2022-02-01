# frozen_string_literal: true

require "services"
require "overlap/holding_commitment"

module Reports
  # Given criteria, pull up all holdings that match those criteria
  # AND are eligible for commitments AND have no commitments.
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
        if overlap.commitments.empty?
          overlap.holdings.each do |h|
            yield [
              h.organization,
              organization_oclc_symbol(h.organization),
              h.ocn,
              h.local_id
            ]
          end
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

  end
end
