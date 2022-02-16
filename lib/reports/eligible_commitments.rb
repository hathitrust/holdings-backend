# frozen_string_literal: true

require "services"
require "overlap/holding_commitment"

module Reports
  # Given criteria, pull up all clusters that  match those criteria
  # AND have holdings,
  # AND have ht_items,
  # AND for those clusters, report holdings that don't have a commitment.
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
        overlap.eligible_holdings.each do |h|
          # Check that the holding does not have a matching commitment
          matching_commitments = overlap.active_commitments.select do |act_com|
            act_com.organization == h.organization && act_com.local_id == h.local_id
          end
          next if matching_commitments.any?
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
