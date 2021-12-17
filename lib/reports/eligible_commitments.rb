# frozen_string_literal: true

require "services"
require "cluster"

Services.mongo!

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

    def for_ocns(ocns = [])
      if ocns.empty?
        raise "No ocns given"
      end

      ocns.sort.uniq.each do |ocn|
        cluster = Cluster.find_by(ocns: [ocn.to_i])

        next if cluster.nil?
        next if we_have_seen? cluster._id
        next unless cluster.eligible_for_commitments?
        next unless cluster.commitments.count.zero?

        cluster.holdings.select(&:eligible_for_commitments?).each do |holding|
          yield [
            holding.organization,
            organization_oclc_symbol(holding.organization),
            holding.ocn,
            holding.local_id
          ]
        end
      end
    end

    def organization_oclc_symbol(org)
      @ht_organizations = Services.ht_organizations
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
