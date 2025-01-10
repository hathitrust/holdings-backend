# frozen_string_literal: true

require "services"
require "enum_chron"
require "json"

module Clusterable
  # A holding
  class Holding
    include EnumChron

    ACCESSOR_ATTRS =
      [
        :ocn,
        :local_id,
        :enum_chron,
        :n_enum,
        :n_chron,
        :n_enum_chron,
        :status,
        :condition,
        :gov_doc_flag,
        :mono_multi_serial,
        :date_received,
        :country_code,
        :weight,
        :uuid,
        :issn
      ]
    READER_ATTRS = [:organization]
    ALL_ATTRS = ACCESSOR_ATTRS + READER_ATTRS

    EQUALITY_EXCLUDED_ATTRS = [:uuid, :date_received]
    EQUALITY_ATTRS = (ALL_ATTRS - EQUALITY_EXCLUDED_ATTRS)

    ACCESSOR_ATTRS.each { |attr| attr_accessor attr }
    READER_ATTRS.each { |attr| attr_reader attr }

    # Changes to the field list must be reflected in `==` and `same_as`
    # XXX: save for now for when we create the table schema
    # field :ocn, type: Integer
    # field :organization, type: String
    # field :local_id, type: String
    # field :enum_chron, type: String, default: ""
    # field :n_enum, type: String, default: ""
    # field :n_chron, type: String, default: ""
    # field :n_enum_chron, type: String, default: ""
    # field :status, type: String
    # field :condition, type: String
    # field :gov_doc_flag, type: Boolean
    # field :mono_multi_serial, type: String
    # field :date_received, type: DateTime
    # field :country_code, type: String
    # field :weight, type: Float
    # field :uuid, type: String
    # field :issn, type: String

    def cluster
      Cluster.for_ocns([ocn]).first
    end

    # validates_presence_of :ocn, :organization, :mono_multi_serial, :date_received
    # validates_inclusion_of :mono_multi_serial, in: ["mix", "mon", "spm", "mpm", "ser"]

    def initialize(params = {})
      params&.transform_keys!(&:to_sym)
      ALL_ATTRS.each do |attr|
        send(attr.to_s + "=", params[attr]) if params[attr]
      end
      set_organization_data if organization
    end

    def organization=(organization)
      @organization = organization
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
      fields = holding_line.split("\t")
      {ocn: fields[0].to_i,
       local_id: fields[1],
       organization: fields[2],
       status: fields[3],
       condition: fields[4],
       date_received: DateTime.parse(fields[5]),
       enum_chron: fields[6],
       mono_multi_serial: fields[7],
       issn: fields[8],
       n_enum: fields[9],
       n_chron: fields[10],
       gov_doc_flag: !fields[11].to_i.zero?,
       uuid: fields[12]}
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
      self.class == other.class &&
        EQUALITY_ATTRS.all? do |attr|
          self_attr = public_send(attr)
          other_attr = other.public_send(attr)

          (self_attr == other_attr) or (blank?(self_attr) and blank?(other_attr))
        end
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

    def to_hash
      ALL_ATTRS.map { |a| [a, send(a)] }.to_h
    end

    # Turn a holding into a hash key for quick lookup
    # in e.g. cluster_holding.find_old_holdings.
    def update_key
      to_hash
        .slice(*EQUALITY_ATTRS)
        # fold blank strings & nil to same update key, as in
        # equality above
        .transform_values { |f| blank?(f) ? nil : f }
        .hash
    end

    private

    def set_organization_data
      self.country_code = Services.ht_organizations[organization].country_code
      self.weight = Services.ht_organizations[organization].weight
    end

    def blank?(value)
      value == "" || value.nil?
    end
  end
end
