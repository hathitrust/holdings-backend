# frozen_string_literal: true

require "mongoid"

# A member holding
class Holding
  include Mongoid::Document
  field :ocn, type: Integer
  field :organization, type: String
  field :local_id, type: String
  field :enum_chron, type: String
  field :status, type: String
  field :condition, type: String
  field :gov_doc_flag, type: Boolean
  field :mono_multi_serial, type: String
  field :date_received, type: DateTime

  embedded_in :cluster

  validates_presence_of :ocn, :organization, :mono_multi_serial, :date_received
  validates_inclusion_of :mono_multi_serial, in: ["mono", "multi", "serial"]


  # Convert a tsv line from a validated holding file into a record like hash
  #
  # @param holding_line, a tsv line
  def self.holding_to_record(holding_line)
    # OCN  BIB  MEMBER_ID  STATUS  CONDITION  DATE  ENUM_CHRON  TYPE  ISSN  N_ENUM  N_CHRON  GOV_DOC
    fields = holding_line.split(/\t/)
    { ocn:               fields[0].to_i,
      organization:      fields[2],
      local_id:          fields[1],
      enum_chron:        fields[6],
      status:            fields[3],
      condition:         fields[4],
      gov_doc_flag:      !fields[10].to_i.zero?,
      mono_multi_serial: fields[7],
      date_received:     DateTime.parse(fields[5]) }
  end

  def self.new_from_holding_file_line(line)
    rec = holding_to_record(line.chomp)
    self.new(rec)
  end

end
