# frozen_string_literal: true

require "mongoid"
require "ht_members"
require "services"
require "enum_chron"
require "json"

# A member holding
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

  embedded_in :cluster

  validates_presence_of :ocn, :organization, :mono_multi_serial, :date_received
  validates_inclusion_of :mono_multi_serial, in: ["mono", "multi", "serial"]

  def initialize(params = nil)
    super
    set_member_data if organization
  end

  def organization=(organization)
    super
    set_member_data
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
  end
  
  # Is false when any field other than date_received or uuid is not the same
  #
  # @param other, another holding
  def ==(other)
    ocn == other.ocn &&
      organization == other.organization &&
      local_id == other.local_id &&
      enum_chron == other.enum_chron &&
      status == other.status &&
      condition == other.condition &&
      gov_doc_flag == other.gov_doc_flag &&
      mono_multi_serial == other.mono_multi_serial
  end

  # Is true when all fields match
  #
  # @param other, another holding
  def same_as?(other)
    (self == other) && (date_received == other.date_received) && (uuid == other.uuid)
  end

  def batch_with?(other)
    ocn == other.ocn
  end

  private

  def set_member_data
    self.country_code = Services.ht_members[organization].country_code
    self.weight       = Services.ht_members[organization].weight
  end

end
