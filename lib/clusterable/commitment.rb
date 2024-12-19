# frozen_string_literal: true

require "shared_print/phases"

module Clusterable
  # A shared print commitment
  class Commitment
    # field :uuid, type: String
    # field :organization, type: String
    # field :ocn, type: Integer
    # field :local_id, type: String
    # field :oclc_sym, type: String
    # field :committed_date, type: DateTime
    # field :retention_date, type: DateTime
    # field :local_bib_id, type: String
    # field :local_item_id, type: String
    # field :local_item_location, type: String
    # field :local_shelving_type, type: String
    # field :policies, type: Array, default: []
    # field :retention_condition, type: String
    # field :facsimile, type: Boolean, default: false
    # field :other_program, type: String
    # field :other_retention_date, type: DateTime
    # field :deprecation_status, type: String
    # field :deprecation_date, type: DateTime
    # field :deprecation_replaced_by, type: String
    # field :phase, type: Integer, default: 0

    # embedded_in :cluster

    # validates_presence_of :uuid, :organization, :ocn, :local_id, :oclc_sym, :committed_date,
    #   :facsimile
    # validates_inclusion_of :local_shelving_type, in: ["cloa", "clca", "sfca", "sfcahm", "sfcaasrs"],
    #   allow_nil: true
    # validates_inclusion_of :policies, in: ["blo", "digitizeondemand", "non-circ", "non-repro"], allow_nil: true

    # validates_inclusion_of :retention_condition, in: ["EXCELLENT", "ACCEPTABLE"], allow_nil: true
    # validate :deprecation_validation
    # validate :other_commitment_validation
    # validate :phase_validation

    def initialize(_params = nil)
      raise "not implemented"
      super
      self.uuid = SecureRandom.uuid
      # Commitments should come with their own committed date, but in case they don't
      # (such as when replacing commitments) we set it to the first of the year.
      # See ticket DEV-206.
      self.committed_date = DateTime.new(Time.now.year, 1, 1) if committed_date.nil?
    end

    def matching_holdings
      cluster = _parent
      cluster.holdings.select { |h| h.organization == organization && h.local_id == local_id }
    end

    def batch_with?(other)
      ocn == other.ocn
    end

    def deprecated?
      # C = duplicate Copy,
      # D = Damaged,
      # E = committed in Error,
      # L = Lost,
      # M = Missing from Print Holdings
      ["C", "D", "E", "L", "M"].include? deprecation_status
    end

    def deprecate(status: "", replacement: nil, date: Date.today)
      self.deprecation_status = status
      self.deprecation_date = date
      self.deprecation_replaced_by = replacement._id unless replacement.nil?
    end

    # Extra policy validation on top of validates_inclusion_of :policies, in: [...]
    def self.incompatible_policies?(policies)
      policies.include?("digitizeondemand") && policies.include?("non-repro")
    end

    private

    # If one of the deprecation fields is set they both must be set
    def deprecation_validation
      if deprecation_status && deprecation_date.nil?
        errors.add(:deprecation_status, "can't be set without a deprecation date.")
      elsif deprecation_status.nil? && deprecation_date
        errors.add(:deprecation_date, "can't be set without a deprecation status.")
      end
    end

    # If one of other_program/other_retention_date is set they must both be set
    def other_commitment_validation
      if other_program && other_retention_date.nil?
        errors.add(:other_program, "cannot be set if other_retention_date is nil")
      elsif other_program.nil? && other_retention_date
        errors.add(:other_retention_date, "cannot be set if other_program is nil")
      end
    end

    def phase_validation
      unless SharedPrint::Phases.list.include?(phase)
        errors.add(:phase, "Not a recognized phase")
      end
    end
  end
end
