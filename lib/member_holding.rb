# frozen_string_literal: true

require "securerandom"
require "json"
require "services"
require "scrub_fields"
require "custom_errors"

# Represents the information in one line from a member holding file
class MemberHolding
  attr_accessor :oclc, :local_id, :organization, :status, :condition,
                :enumchron, :mono_multi_serial, :issn, :govdoc

  attr_reader :uuid, :date_received, :n_enum, :n_chron, :violations

  def initialize(col_map = {})
    @col_map       = col_map
    @scrubfields   = ScrubFields.new
    @violations    = []
    @date_received = Time.new.strftime("%Y-%m-%d")
    @uuid          = SecureRandom.uuid
  end

  def log(str)
    Services.scrub_logger.info(str)
  end

  # Takes a line from a member holding file
  # and populates a MemberHolding-object
  def parse_str(str)
    if str.nil? || str.class != String || str.empty?
      raise ColValError, "bad str (class #{str.class}): #{str}"
    end

    cols = str.split("\t")
    if cols.size != @col_map.keys.size
      @violations << "Wrong number of cols " \
        "(expected #{@col_map.keys.size}, got #{cols.size})"

    end

    @col_map.each do |col_type, col_no|
      # puts "@uuid:#{@uuid}, set(#{col_type}, #{cols[col_no]})"
      set(col_type, cols[col_no])
    end

    @violations.empty?
  end

  # Given a column name and a value, sets the proper attribute
  # via ScrubFields
  # rubocop:disable Metrics/MethodLength
  def set(col_type, col_val)
    if col_val.nil? || col_val.class != String
      raise ColValError,
            "col_val for col_type #{col_type} empty/nil/wrong class"
    end

    case col_type
    when "oclc"
      @ocn = @scrubfields.ocn(col_val)
      if @ocn.empty?
        @violations << "No valid OCN"
      end
    when "local_id"
      @local_id = @scrubfields.local_id(col_val)
    when "status"
      @status = @scrubfields.status(col_val)
    when "condition"
      @condition = @scrubfields.condition(col_val)
    when "govdoc"
      @gov_doc_flag = @scrubfields.govdoc(col_val)
    when "enumchron"
      @enum_chron = col_val
      normalized = @scrubfields.enumchron(col_val)
      @n_enum  = normalized[0]
      @n_chron = normalized[1]
    when "issn"
      @issn = @scrubfields.issn(col_val)
    else
      raise ColValError,
            "cannot handle column type #{col_type} (value: #{col_val})"
    end
  end
  # rubocop:enable Metrics/MethodLength

  def to_json(*_args)
    {
      ocn:               @ocn,
      local_id:          @local_id,
      organization:      organization,
      status:            @status,
      condition:         @condition,
      enum_chron:        @enum_chron,
      mono_multi_serial: mono_multi_serial,
      issn:              @issn,
      gov_doc_flag:      @gov_doc_flag,
      uuid:              @uuid,
      date_received:     @date_received,
      n_enum:            @n_enum,
      n_chron:           @n_chron
    }.to_json
  end

end
