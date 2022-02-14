# frozen_string_literal: true

require "services"
require "enum_chron_parser"
require "scrub/max_ocn"

module Scrub
  # This class knows how to extract and validate certain values
  # from a member submission file.
  class ScrubFields
    # "444; 555; 666" -> %w[444,555,666]
    OCN_SPLIT_DELIM = /[,:;|\/ ]+/
    LOCAL_ID_SPLIT_DELIM = /[,; ]+/
    ISSN_DELIM = LOCAL_ID_SPLIT_DELIM

    # (ocolc)555 / (abc)555
    PAREN_PREFIX = /^\(.+?\)/
    OK_PAREN_PREFIX = /\((oclc|ocm|ocn|ocolc)\)/i

    # ocn555 / abc555
    PREFIX = /^\D+/
    OK_PREFIX = /(oclc|ocm|ocn|ocolc)/i

    # No prefix, just "555", could be an ocn so we assume it is
    JUST_DIGITS = /^\d+$/

    # any garbage that just doesn't have any numbers
    NO_NUMBERS = /^\D+$/

    # someone exported a big num from excel, e.g. 1.1e+567
    EXPONENTIAL = /\d[Ee]\+?\d/

    # 55NEW55
    DIGIT_MIX = /^\d+\D/

    # for capturing the numeric part
    NUMERIC_PART = /(\d+)/

    LOCAL_ID_MAX_LEN = 50
    MAX_NUM_ITEMS = 25 # rather arbitrary

    STATUS = /^(CH|LM|WD)$/
    CONDITION = /^BRT$/
    GOVDOC = /^[01]$/
    ISSN = /^\d{4}-?\d{3}[0-9Xx]$/

    attr_accessor :logger

    def initialize
      # Get current max oclc
      @current_max_ocn = Scrub::MaxOcn.new.ocn
      @ec_parser = EnumChronParser.new
      if @current_max_ocn.nil?
        raise "failed to set current_max_ocn"
      end
    end

    # Given a string, determines which valid ocns are in it,
    # and returns them as a uniq'd array of Integers.
    def ocn(str)
      ok_ocns = []
      return ok_ocns if str.nil?

      count_x("rec_with_ocn")
      candidates = str.split(OCN_SPLIT_DELIM).map(&:strip)

      # TODO: maybe we don't care about this?
      # I've found it to be a good indicator that the record wasn't
      # exported properly, but there are legit cases of this I guess.
      if candidates.size > MAX_NUM_ITEMS
        count_x(:too_many_ocns)
        Services.scrub_logger.warn "A lot of ocns (#{candidates.size}) in ocn #{str}"
      end

      if candidates.size > 1
        count_x(:multi_ocn_record)
      end

      candidates.each do |candidate|
        catch(:rejected_value) do
          ok_ocn = try_to_reject_ocn(candidate.strip)
          unless ok_ocn.nil?
            ok_ocns << ok_ocn
          end
        end
      end

      # Not resolving OCNs at this point, just taking the uniq numbers.
      ok_ocns.uniq
    end

    # Try to find a reason to reject the candidate ocn.
    # Any time reject_value triggers, it throws :rejected_value
    # and we go back out to the catch statement in ocn(str)
    def try_to_reject_ocn(candidate)
      candidate.nil? &&
        reject_value("ocn is nil")

      candidate.empty? &&
        reject_value("ocn is empty")

      EXPONENTIAL.match?(candidate) &&
        reject_value("ocn is in exponential format", candidate)

      DIGIT_MIX.match?(candidate) &&
        reject_value("ocn is mix of digits and non-digits", candidate)

      # Check prefixes, w/wo parens
      if PAREN_PREFIX.match(candidate)
        paren_expr = Regexp.last_match(0)
        count_x("ocn_paren #{paren_expr}")
        OK_PAREN_PREFIX.match?(paren_expr) ||
          reject_value("ocn has an invalid paren prefix", candidate)
      elsif PREFIX.match(candidate)
        prefix_expr = Regexp.last_match(0)
        count_x("ocn_prefix #{paren_expr}")
        OK_PREFIX.match?(prefix_expr) ||
          reject_value("ocn has an invalid prefix", candidate)
      end

      numeric_part = capture_numeric(candidate)
      # As far as the numeric part goes, the only thing we can say
      # about it is that it should be smaller than the current max ocn.
      numeric_part > current_max_ocn &&
        reject_value("too large for an ocn", numeric_part)

      numeric_part.zero? &&
        reject_value("ocn is zero", candidate)

      numeric_part
    end

    def local_id(str)
      # Given a string, checks if there are any valid-looking local_ids
      # and returns it/them as an array of strings.
      output = []
      return output if str.nil?

      candidates = str.strip.split(LOCAL_ID_SPLIT_DELIM)

      if candidates.size > 1
        Services.scrub_logger.warn "there are #{candidates.size} candidates in this local_id"
        # TODO: maybe throw something??
      end

      if candidates.size > MAX_NUM_ITEMS
        Services.scrub_logger.error "in fact lots of items #{candidates.size} in local_id #{str}"
        # maybe definitely throw something??
      end

      candidates.each do |candidate|
        catch(:rejected_value) do
          candidate.size > LOCAL_ID_MAX_LEN &&
            reject_value(
              format(
                "local_id too long (%i > max %i)",
                candidate.size,
                LOCAL_ID_MAX_LEN
              ),
              candidate
            )
          output << candidate
        end
      end
      output.uniq
    end

    # Given a string, checks if there are any valid-looking issns,
    # Returns a bit of a mess...
    # ... a  single element array, where [0] is a ;-joined string.
    def issn(str)
      candidates = str.split(ISSN_DELIM)
      ok_issns = []

      candidates.each do |candidate|
        catch(:rejected_value) do
          ISSN.match?(candidate) ||
            reject_value("not an OK issn", candidate)

          ok_issns << candidate
        end
      end

      output = ok_issns.join(";")
      [output]
    end

    # Given an enumchron str, returns an array with a norm'd enum and norm'd chron
    # The enumchron parser is ancient, murky & probably not the best.
    def enumchron(str)
      ec_parser.parse(str)
      [ec_parser.normalized_enum, ec_parser.normalized_chron]
    end

    # checks that the given string contains an ok status
    def status(str)
      simple_matcher(STATUS, str)
    end

    # checks that the given string contains an ok condition
    def condition(str)
      simple_matcher(CONDITION, str)
    end

    # checks that the given string contains an ok govdoc
    def govdoc(str)
      simple_matcher(GOVDOC, str)
    end

    private

    # DRY code for the status, condition and govdoc functions
    def simple_matcher(rx, str)
      # Get the name of the calling method
      cmeth = caller_locations(1..1).first.label
      output = []
      str = str.strip
      unless str.empty?
        match = rx.match(str)
        if match.nil?
          Services.scrub_logger.warn "bad #{cmeth} value: \"#{str}\""
        else
          output << match[0]
        end
      end
      count_x("#{cmeth}:#{str}")

      output
    end

    # Directly throws :rejected_value
    def reject_value(reason, val = "")
      count_x("value rejected: #{reason} (#{val})")
      throw :rejected_value
    end

    def count_x(x)
      Services.scrub_stats[x.to_sym] ||= 0
      Services.scrub_stats[x.to_sym] += 1
    end

    # May indirectly throw :rejected_value
    def capture_numeric(str)
      md = str.match(NUMERIC_PART)
      md.nil? && reject_value("could not extract numeric part from ocn", str)
      md[0].to_i
    end

    attr_reader :current_max_ocn, :ec_parser
  end
end
