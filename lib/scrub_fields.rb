# frozen_string_literal: true

require 'enum_chron_parser';
                    
class ScrubFields

  # "444; 555; 666" -> %w[444,555,666]
  OCN_SPLIT_DELIM      = /[,:;\|\/ ]+/.freeze
  LOCAL_ID_SPLIT_DELIM = /[,; ]+/.freeze
  ISSN_DELIM           = LOCAL_ID_SPLIT_DELIM

  # (ocolc)555 / (abc)555
  PAREN_PREFIX    = /^\(.+?\)/.freeze
  OK_PAREN_PREFIX = /\((oclc|ocm|ocn|ocolc)\)/i.freeze

  # ocn555 / abc555
  PREFIX = /^\D+/.freeze
  OK_PREFIX = /(oclc|ocm|ocn|ocolc)/i.freeze

  # No prefix, just "555", could be an ocn so we assume it is
  JUST_DIGITS = /^\d+$/.freeze

  # any garbage that just doesn't have any numbers
  NO_NUMBERS = /^\D+$/.freeze

  # someone exported a big num from excel, e.g. 1.1e+567
  EXPONENTIAL = /\d[Ee]\+?\d/.freeze

  # 55NEW55
  DIGIT_MIX = /^\d+\D/.freeze

  # for capturing the numeric part
  NUMERIC_PART = /(\d+)/.freeze

  # Get current max oclc
  # TODO: maybe rewrite this in ruby for testability / less crappiness
  max_ocn = `bash #{__dir__}/get_max_ocn.sh`.split("\n").last
  CURRENT_MAX_OCN = if !max_ocn.nil? then
                      max_ocn.strip!
                      if JUST_DIGITS.match?(max_ocn) then
                        max_ocn.to_i
                      else
                        nil
                      end
                    end

  if CURRENT_MAX_OCN.nil? then
    raise "failed to set CURRENT_MAX_OCN"
  end

  LOCAL_ID_MAX_LEN = 50
  MAX_NUM_ITEMS    = 10 # rather arbitrary

  STATUS    = /^(CH|LM|WD)$/.freeze
  CONDITION = /^BRT$/.freeze
  GOVDOC    = /^[01]$/.freeze
  ISSN      = /^\d{4}-?\d{3}[0-9Xx]$/.freeze

  EC_PARSER = EnumChronParser.new
  
  # Given a string, determines which valid ocns are in it,
  # and returns them as a uniq'd array of Integers.
  def self.ocn(str)
    output = []
    return output if str.nil?

    str.strip!
    candidates = str.split(OCN_SPLIT_DELIM)

    if candidates.size > MAX_NUM_ITEMS then
      warn "Too many items (#{candidates.size}) in ocn #{str}";
    end

    # DO WHILE MAYBE COMEFROM reject_value
    candidates.each do |candidate|
      catch(:rejected_value) do
        numeric_part = capture_numeric(candidate)
        candidate.strip!

        # Try to find a reason to reject the candidate ocn
        # Any time reject_value triggers, go ^^ to the catch.
        candidate.nil? &&
          reject_value("ocn is nil", "")

        candidate.empty? &&
          reject_value("ocn is empty", "")

        EXPONENTIAL.match?(candidate) &&
          reject_value("ocn is in exponential format", candidate)

        DIGIT_MIX.match?(candidate) &&
          reject_value("ocn is mix of digits and non-digits", candidate)

        # Check prefixes, with / without parens
        if PAREN_PREFIX.match(candidate) then
          paren_expr = Regexp.last_match(0)
          OK_PAREN_PREFIX.match?(paren_expr) ||
            reject_value("ocn has an invalid paren prefix", candidate)
        elsif PREFIX.match(candidate) then
          prefix_expr = Regexp.last_match(0)
          OK_PREFIX.match?(prefix_expr) ||
            reject_value("ocn has an invalid prefix", candidate)
        end

        # As far as the numeric part goes, the only thing we can say
        # about it is that it should be smaller than the current max ocn.
        numeric_part > CURRENT_MAX_OCN &&
          reject_value("number is too large for an ocn", numeric_part)

        numeric_part.zero? &&
          reject_value("ocn is zero", candidate)

        # If we made it this far, we assume candidate is OK.
        output << numeric_part
      end
    end

    # TODO? Resolve ocns and return uniq resolved?
    output.uniq!
    return output
  end

  def self.local_id(str)
    output = []
    return output if str.nil?

    str.strip!
    candidates = str.split(LOCAL_ID_SPLIT_DELIM)

    if candidates.size > 1 then
      warn "there are #{candidates.size} candidates in this local_id"
      # maybe throw something??
    end

    if candidates.size > MAX_NUM_ITEMS then
      warn "in fact lots of items #{candidates.size} in local_id #{str}";
      # maybe definitely throw something??
    end

    candidates.each do |candidate|
      catch(:rejected_value) do
        puts "looking at local_id #{candidate}"
        candidate.size > LOCAL_ID_MAX_LEN &&
          reject_value(
            "local_id too long (%i > max %i)" %
            [candidate.size, LOCAL_ID_MAX_LEN],
            candidate
          )
        output << candidate
      end
    end
    output.uniq!

    return output
  end

  def self.issn(str)
    candidates = str.split(ISSN_DELIM)
    ok_issns   = []

    candidates.each do |candidate|
      catch(:rejected_value) do
        ISSN.match?(candidate) ||
          reject_value("not an OK issn", candidate)

        ok_issns << candidate
      end
    end

    output = ok_issns.join(";")
    return [output]
  end

  # Given an enumchron str, returns an array with a norm'd enum and norm'd chron
  # The enumchron parser is ancient, murky & probably not the best.
  def self.enumchron(str)
    EC_PARSER.parse(str)
    return [EC_PARSER.normalized_enum, EC_PARSER.normalized_chron]
  end

  def self.status(str)
    simple_matcher(STATUS, str)
  end

  def self.condition(str)
    simple_matcher(CONDITION, str)
  end

  def self.govdoc(str)
    simple_matcher(GOVDOC, str)
  end

  def self.simple_matcher(rx, str)
    output = []
    str.strip!
    rx.match(str) &&
      output << Regexp.last_match(0)

    return output
  end

  # Throws :rejected_value
  def self.reject_value(reason, val)
    warn [reason, val].join(":")
    throw :rejected_value
  end

  # Throws :rejected_value
  def self.capture_numeric(str)
    md = str.match(NUMERIC_PART)
    if !md.nil? then
      return md[0].to_i
    else
      reject_value("could not extract numeric part", str)
    end
  end

end
