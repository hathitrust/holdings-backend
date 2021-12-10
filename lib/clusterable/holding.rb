# frozen_string_literal: true

require "mongoid"
require "services"
require "enum_chron"
require "json"

module Clusterable

  # A holding
  class Holding
    include Mongoid::Document
    include EnumChron
    # Changes to the field list must be reflected in `==` and `same_as`
    field :ocn, type: Integer
    field :organization, type: String
    field :local_id, type: String
    field :enum_chron, type: String, default: ""
    field :n_enum, type: String, default: ""
    field :n_chron, type: String, default: ""
    field :n_enum_chron, type: String, default: ""
    field :status, type: String
    field :condition, type: String
    field :gov_doc_flag, type: Boolean
    field :mono_multi_serial, type: String
    field :date_received, type: DateTime
    field :country_code, type: String
    field :weight, type: Float
    field :uuid, type: String
    field :issn, type: String

    EQUALITY_EXCLUDED_FIELDS = ["_id", "uuid", "date_received"].freeze

    embedded_in :cluster

    validates_presence_of :ocn, :organization, :mono_multi_serial, :date_received
    validates_inclusion_of :mono_multi_serial, in: ["mono", "multi", "serial"]

    def initialize(params = nil)
      super
      set_organization_data if organization
    end

    def organization=(organization)
      super
      set_organization_data
    end

    def brt_lm_access?
      condition == "BRT" || status == "LM"
    end

    # Convert a tsv line from a validated holding file into a record like hash
    #
    # @param holding_line, a tsv line
    def self.holding_to_record(holding_line)
      # OCN  BIB  MEMBER_ID  STATUS  CONDITION  DATE  ENUM_CHRON  TYPE  \
      # ISSN  N_ENUM  N_CHRON  GOV_DOC UUID
      fields = holding_line.split(/\t/)
      { ocn:               fields[0].to_i,
        local_id:          fields[1],
        organization:      fields[2],
        status:            fields[3],
        condition:         fields[4],
        date_received:     DateTime.parse(fields[5]),
        enum_chron:        fields[6],
        mono_multi_serial: fields[7],
        issn:              fields[8],
        n_enum:            fields[9],
        n_chron:           fields[10],
        gov_doc_flag:      !fields[11].to_i.zero?,
        uuid:              fields[12] }
    end

    def self.new_from_holding_file_line(line)
      rec = holding_to_record(line.chomp)
      new(rec)
    end

    def self.new_from_scrubbed_file_line(line)
      rec = JSON.parse(line)
      new(rec)
    end

    # Is false when any field other than _id, date_received or uuid is not the
    # same
    #
    # @param other, another holding
    def ==(other)
      (fields.keys - EQUALITY_EXCLUDED_FIELDS)
        .all? {|attr| public_send(attr) == other.public_send(attr) }
    end

    # Is true when all fields match except for _id
    #
    # @param other, another holding
    def same_as?(other)
      (self == other) &&
        (date_received == other.date_received) &&
        (uuid == other.uuid)
    end

    def batch_with?(other)
      ocn == other.ocn
    end

    # Turn a holding into a hash key for quick lookup
    # in e.g. cluster_holding.find_old_holdings.
    def update_key
      as_document.slice(*(fields.keys - EQUALITY_EXCLUDED_FIELDS)).hash
    end

    def matches_commitment?
      # check if there is a commitment on the same cluster
      # with the same org & local_id
      cluster.commitments.select do |spc|
        spc.organization == organization && spc.local_id == local_id
      end.any?
    end

    def eligible_for_commitment?
      # TODO: check if it matches the criteria for shared print
      true
    end

    private

    def set_organization_data
      self.country_code = Services.ht_organizations[organization].country_code
      self.weight       = Services.ht_organizations[organization].weight
    end

  end
end
