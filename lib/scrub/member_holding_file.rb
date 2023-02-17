# frozen_string_literal: true

require "scrub/file_name_error"
require "scrub/malformed_record_error"
require "scrub/member_holding"
require "scrub/member_holding_header_factory"
require "scrub/scrub_fields"
require "services"
require "utils/agnostic_opener"

module Scrub
  # Context:
  # Objects of this class represent files submitted by (prospective)
  # members, to be loaded.
  # Individual lines are represented by MemberHolding objects.
  # MemberHoldingFile objects are generated by AutoScrub.
  class MemberHoldingFile
    attr_reader :error_count
    # private perhaps?
    attr_reader :col_map, :member_id, :filename, :filepath

    SPEC_RX = {
      # A single regex for file name pass/fail.
      FILENAME: /^
      [a-z\-]+               # member_id
      _(mix|mon|spm|mpm|ser) # item_type
      _(full|partial)        # update_type
      _\d{8}                 # date_str (loosest possible YYYYMMDD check)
      (_.+)?                 # optional "rest" part
      .tsv                   # must have a .tsv extension
      (.gz)?                 # may have a .gz extension
      $/x,

      # Split filename on these to get the individual parts.
      FILENAME_PART_DELIM: /[_.]/,

      # If filename fail, further regexes to discover why.
      MEMBER_ID: /^[a-z_\-]+$/,
      ITEM_TYPE: /^(mix|mon|spm|mpm|ser)$/,
      ITEM_TYPE_CONTEXT: /_(mix|mon|spm|mpm|ser)_/,
      UPDATE_TYPE: /^(full|partial)$/,

      # A YYYYMMDD date string is expected,
      # and of course this regex is overly permissive
      # but let's leave it like that.
      DATE: /^\d{8}$/
    }.freeze

    def initialize(path)
      @filepath = path
      @filename = File.basename(path)
      @error_count = 0
      @item_type = item_type_from_filename
      @member_id = member_id_from_filename

      # get a file
      # check filename for member_id, item_type etc.
      # parse header & set up the column map
      # check individual lines
    end

    def log(msg)
      Services.scrub_logger.info(msg)
    end

    def parse(&block)
      unless valid_filename?
        raise Scrub::FileNameError, "Invalid filename #{@filename}"
      end

      scrub_stats = Services.scrub_stats
      each_holding(&block)
      log("Scrub stats:")
      scrub_stats.keys.sort.each do |ssk|
        log("#{ssk}\t#{scrub_stats[ssk]}")
      end

      scrub_stats = {}
    end

    def member_id_from_filename(fn_str = @filename)
      if fn_str.nil? || fn_str.empty?
        raise Scrub::FileNameError, "Empty filename"
      end

      parts = fn_str.split("_")
      member_id = parts.first

      if SPEC_RX[:MEMBER_ID].match(member_id)
        log("OK member_id #{member_id} in filename #{@filename}")
        member_id
      else
        raise Scrub::FileNameError, "Did not find a member_id in filename (#{fn_str})"
      end
    end

    def item_type_from_filename(fn_str = @filename)
      if SPEC_RX[:ITEM_TYPE_CONTEXT].match(fn_str)
        item_type = Regexp.last_match(1)
        log("OK item_type (#{item_type}) from filename (#{@filename})")
        item_type
      else
        raise Scrub::FileNameError, "Did not find item_type in filename (#{fn_str})"
      end
    end

    # Check that a filename conforms to spec.
    def valid_filename?
      # If it matches, perfect, we don't need to analyze or report.
      log("Check filename #{@filename}")

      if SPEC_RX[:FILENAME].match?(@filename)
        log("Filename #{@filename} OK!")
        return true
      end

      # If we made it here, the match failed, so break it down & return false.
      (f_member_id, f_item_type, f_update_type, f_date_str, *f_rest) =
        @filename.split(SPEC_RX[:FILENAME_PART_DELIM])

      msg = [
        "Processing of #{@filename} failed due to filename errors.",
        "Filename must match the template:",
        "<member_id>_<item_type>_<update_type>_<date_str>_<rest>",
        "Filename was analyzed as:",
        "member_id\t\"#{f_member_id}\"\t#{analyze_member_id(f_member_id)}",
        "item_type\t\"#{f_item_type}\"\t#{analyze_item_type(f_item_type)}",
        "update_type\t\"#{f_update_type}\"\t#{analyze_update_type(f_update_type)}",
        "date_str\t\"#{f_date_str}\"\t#{analyze_date_str(f_date_str)}",
        "rest\t\"#{f_rest.join(" ")}\"\t#{analyze_rest(f_rest)}"
      ].join("\n")
      log(msg)
      false
    end

    def analyze_member_id(potential_member_id)
      not_nil_and_match(potential_member_id, SPEC_RX[:MEMBER_ID])
    end

    def analyze_item_type(potential_item_type)
      not_nil_and_match(potential_item_type, SPEC_RX[:ITEM_TYPE])
    end

    def analyze_update_type(potential_update_type)
      not_nil_and_match(potential_update_type, SPEC_RX[:UPDATE_TYPE])
    end

    def analyze_date_str(potential_date_str)
      not_nil_and_match(potential_date_str, SPEC_RX[:DATE])
    end

    # Shortcut for the analyze_x methods above.
    # Checks that str is not nil, and matches regexp
    # otherwise issues a warning.
    def not_nil_and_match(str, regexp)
      warning = "must match #{regexp}"
      if str.nil?
        "must not be empty, and #{warning}"
      elsif regexp.match?(str)
        "ok"
      else
        "not ok: #{warning}"
      end
    end

    # 'rest' is the remaining part of the filename, after the required
    # parts, and includes the required file extension(s).
    # This is so we can allow umich_mon_full_20201230.tsv
    # as well as              umich_mon_full_20201230_fix_pt2.tsv.gz
    def analyze_rest(arr)
      return "must not be empty" if arr.empty?

      # magic numbers abound
      if arr.size > 10 || arr.join.length > 100
        return "not ok, too long"
      end

      if arr[-1] == "tsv" || (arr[-2] == "tsv" && arr[-1] == "gz")
        return "ok"
      end

      "not ok, must end in .tsv or .tsv.gz"
    end

    def each_holding(&block)
      read_file do |line, line_no, col_map|
        # May be more than one, if multiple ocns
        item_from_line(line, col_map).each(&block)
      rescue Scrub::MalformedRecordError => e
        log("Rejected record #{filename}:#{line_no}, #{e.message}")
      end
    end

    def item_from_line(line, col_map)
      if line.nil? || line.empty?
        raise Scrub::MalformedRecordError, "bad line (nil/empty)"
      end

      holding = MemberHolding.new(col_map)
      all_ok = holding.parse(line)

      unless all_ok
        raise Scrub::MalformedRecordError, holding.violations.join(" // ")
      end

      holding.organization = @member_id
      holding.mono_multi_serial = @item_type

      holding.explode_ocn
    end

    def read_file
      Utils::AgnosticOpener.new(filepath).open do |fh|
        header = MemberHoldingHeaderFactory.for(@item_type, fh.readline)
        col_map = header.get_col_map
        line_no = 0
        fh.each_line do |line|
          line_no += 1
          line.chomp!
          yield line, line_no, col_map
        end
      end
    end
  end
end
