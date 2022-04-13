# frozen_string_literal: true

require "mongoid"

module Clusterable
  # A shared print commitment
  class Commitment
    include Mongoid::Document
    field :uuid, type: String
    field :organization, type: String
    field :ocn, type: Integer
    field :local_id, type: String
    field :oclc_sym, type: String
    field :committed_date, type: DateTime
    field :retention_date, type: DateTime
    field :local_bib_id, type: String
    field :local_item_id, type: String
    field :local_item_location, type: String
    field :local_shelving_type, type: String
    field :policies, type: Array, default: []
    field :facsimile, type: Boolean, default: false
    field :other_program, type: String
    field :other_retention_date, type: DateTime
    field :deprecation_status, type: String
    field :deprecation_date, type: DateTime
    field :deprecation_replaced_by, type: String

    embedded_in :cluster

    validates_presence_of :uuid, :organization, :ocn, :local_id, :oclc_sym, :committed_date,
      :facsimile
    validates_inclusion_of :local_shelving_type, in: ["cloa", "clca", "sfca", "sfcahm", "sfcaasrs"],
      allow_nil: true
    validate :deprecation_validation

    def initialize(_params = nil)
      super
      self.uuid = SecureRandom.uuid
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

    private

    # If one of the deprecation fields is set they both must be set
    def deprecation_validation
      if deprecation_status && deprecation_date.nil?
        errors.add(:deprecation_status, "can't be set without a deprecation date.")
      elsif deprecation_status.nil? && deprecation_date
        errors.add(:deprecation_date, "can't be set without a deprecation status.")
      end
    end
  end
end
