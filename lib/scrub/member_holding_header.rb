# frozen_string_literal: true

require "services"
require "scrub/malformed_header_error"

module Scrub
  # Context: This class is responsible for knowing the internals
  # of the header line in a member_holding_file.
  #
  # MemberHoldingHeaderFactory generates one of its subclasses.
  class MemberHoldingHeader
    attr_reader :opt_header_cols, :req_header_cols, :col_map

    def initialize(header_line)
      @header_line = header_line.chomp

      # strip UTF-8 BOM
      utf8_bom_regex = /^\xEF\xBB\xBF/
      @header_line.gsub!(utf8_bom_regex, "")

      Services.scrub_logger.info("Getting header information from: #{header_line}")

      @cols = @header_line.downcase.split("\t")
      @cols.each do |col|
        col.gsub!(/\s+/, "")
      end
      # Required header columns for all files
      @req_header_cols = ["oclc", "local_id"]
    end

    def possible_cols
      @req_header_cols + @opt_header_cols
    end

    # Check that the header line is present,
    # contains all required fields, optionally optional fields,
    # and nothing else. Returns a [] of violations for logging.
    def check_violations
      violations = []

      # Check that all required cols are present
      unless (@req_header_cols - @cols).empty?
        violations << "Missing required header cols:" +
          (@req_header_cols - @cols).join(", ")
      end

      # Note any cols that are not required/optional and ignore
      illegal_cols = (@cols - (@req_header_cols + @opt_header_cols))

      unless illegal_cols.empty?
        allowed_cols = (@req_header_cols + @opt_header_cols).join(", ")
        violations << [
          "The following cols are not allowed for a #{self.class}:",
          illegal_cols.join(","),
          "... given header_line:",
          @header_line,
          "Allowed cols are: #{allowed_cols}"
        ].join("\n")
      end

      violations
    end

    # Given a split header line like [a,b,c]
    # returns a hash {a=>1, b=>2, c=>3}
    def get_col_map
      col_map = {}

      # only elements in possible_cols get included in col_map
      @cols.each_with_index do |col, i|
        if possible_cols.include?(col)
          col_map[col] = i
        else
          raise Scrub::MalFormedHeaderError,
            "Column #{col} is not allowed. Possible columns are: #{possible_cols.join(", ")}"
        end
      end

      if col_map.empty?
        raise Scrub::MalFormedHeaderError,
          "Found no usable column headers among #{@cols}"
      end

      violations = check_violations
      unless violations.empty?
        Services.scrub_logger.warn(violations.join("\n"))
      end

      col_map
    end
  end

  # Subclass for mix
  class MixHoldingHeader < MemberHoldingHeader
    def initialize(header_line)
      super
      @opt_header_cols = [
        "govdoc"
      ]
    end
  end

  # Subclass for mon
  class MonHoldingHeader < MemberHoldingHeader
    def initialize(header_line)
      super
      @opt_header_cols = [
        "status",
        "condition",
        "govdoc",
        "enum_chron"
      ]
    end
  end

  # Subclass for spm
  class SpmHoldingHeader < MemberHoldingHeader
    def initialize(header_line)
      super
      @opt_header_cols = [
        "status",
        "condition",
        "govdoc"
      ]
    end
  end

  # Subclass for mpm
  class MpmHoldingHeader < MemberHoldingHeader
    def initialize(header_line)
      super
      @req_header_cols << "enum_chron"
      @opt_header_cols = [
        "status",
        "condition",
        "govdoc"
      ]
    end
  end

  # Subclass for ser
  class SerHoldingHeader < MemberHoldingHeader
    def initialize(header_line)
      super
      @opt_header_cols = [
        "govdoc",
        "issn"
      ]
    end
  end
end
