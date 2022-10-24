# frozen_string_literal: true

require "securerandom"
require "json"
require "services"
require "scrub/scrub_fields"
require "scrub/col_val_error"

module Scrub
  # Represents the information in one line from a member holding file
  class MemberHolding
    attr_accessor :organization, :mono_multi_serial, :ocn, :uuid

    attr_reader :local_id, :status, :condition, :enum_chron, :issn,
      :gov_doc_flag, :date_received, :n_enum, :n_chron,
      :violations

    def initialize(col_map = {})
      @col_map = col_map
      @scrubfields = ScrubFields.new
      @violations = []
      @date_received = Time.new.strftime("%Y-%m-%d")
      @uuid = SecureRandom.uuid
    end

    def log(msg)
      Services.scrub_logger.info(msg)
    end

    # Takes a line from a member holding file
    # and populates a MemberHolding-object
    def parse(str)
      if str.nil? || str.empty?
        raise Scrub::ColValError, "bad str (class #{str.class}): #{str}"
      end
      cols = split_preserve_trailing(str, "\t")
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
    def set(col_type, col_val)
      if col_val.nil?
        Services.scrub_logger.warn("col_val for col_type #{col_type} is nil")
        col_val = ""
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
        @n_enum = normalized[0]
        @n_chron = normalized[1]
      when "issn"
        @issn = @scrubfields.issn(col_val)
      else
        raise Scrub::ColValError,
          "cannot handle column type #{col_type} (value: #{col_val})"
      end
    end

    # In case a MemberHolding.ocn has more than one value, we need to
    # explode into 1 MemberHolding per ocn.
    def explode_ocn
      siblings = []

      if ocn.size == 1
        @ocn = ocn.first
        return [self]
      end

      log("Exploding OCNs: #{ocn.join(",")}")
      @ocn.each do |ocn|
        doppel = clone
        doppel.ocn = ocn
        doppel.uuid = SecureRandom.uuid
        siblings << doppel
      end

      siblings
    end

    def to_json(*_args)
      {
        ocn: ocn,
        local_id: local_id,
        organization: organization,
        status: status,
        condition: condition,
        enum_chron: enum_chron,
        mono_multi_serial: mono_multi_serial,
        issn: issn,
        gov_doc_flag: gov_doc_flag,
        uuid: uuid,
        date_received: date_received,
        n_enum: n_enum,
        n_chron: n_chron
      }.to_json
    end

    private

    # Traditional split removes any trailing nils, meaning
    # "123|456|".split("|") # => ["123", "456"]
    # and split_preserve_trailing is what you need if you want
    # ["123", "456", ""] instead.
    # Holdings files can contain lines ending with empty values,
    # so we need to do something to preserve them. This is that.
    def split_preserve_trailing(str, pat)
      # Check if str ends with any number of split delimiters.
      md = str.match(/(#{pat}+)$/)
      if md.nil?
        # If not, fine, just split as normal.
        str.split(pat)
      else
        # But if it did, fill up the return array with as many empty strings.
        str.split(pat) + ([""] * md[1].size)
      end
    end
  end
end
