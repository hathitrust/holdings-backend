require 'securerandom'
require 'json'

class MemberHolding
  attr_accessor :oclc, :local_id, :organization, :status, :condition,
    :enumchron, :mono_multi_serial, :issn, :govdoc

  attr_reader :uuid, :date_received, :n_enum, :n_chron

  def initialize
    @date_received = Time.new.strftime("%Y-%m-%d")
    @uuid = SecureRandom.uuid
  end

  def to_json
    # TODO: input uses 'ocn', not 'oclc'; 
    #       gov_doc_flag, not 'govdoc';
    #       enum_chron, not enumchron
    {ocn: oclc,
     local_id: local_id,
     organization: organization,
     status: status,
     condition: condition,
     enum_chron: enumchron,
     mono_multi_serial: mono_multi_serial,
     issn: issn,
     gov_doc_flag: govdoc,
     uuid: uuid,
     date_received: date_received,
     n_enum: n_enum,
     n_chron: n_chron}.to_json
  end

  # accept a incoming line
  # produce scrubbed JSON

  # parse scrubbed JSON to Holding??

  # extracting individual fields as objects with validation methods?
end
