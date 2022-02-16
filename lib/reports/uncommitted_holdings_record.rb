# frozen_string_literal: true

require "services"

module Reports
  # Wrapper around a Clusterable::Holding for use in Reports::UncommittedHoldings.
  class UncommittedHoldingsRecord
    attr_reader :organization, :oclc_sym, :ocn, :local_id
    def initialize(holding)
      @organization = holding.organization
      @oclc_sym = Services.ht_organizations.members.fetch(@organization)&.oclc_sym || "N/A"
      @ocn = holding.ocn
      @local_id = holding.local_id
    end

    def to_a
      [organization, oclc_sym, ocn, local_id]
    end

    def to_s
      to_a.join("\t")
    end
  end
end
