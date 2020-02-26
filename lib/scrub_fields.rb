# frozen_string_literal: true

class ScrubFields

  # "444; 555; 666" -> %w[444,555,666]
  SPLIT_DELIM = Regexp.new(/[,:;\|\/ ]+/)

  # (ocolc)555 / (abc)555
  PAREN_PREFIX    = Regexp.new(/^\(.+?\)/)
  OK_PAREN_PREFIX = Regexp.new(/\((oclc|ocm|ocn|ocolc)\)/i)

  # ocn555
  PREFIX = Regexp.new(/^\D+/)
  OK_PREFIX = Regexp.new(/(oclc|ocm|ocn|ocolc)/i)
  
  # No prefix, just "555", could be an ocn so we assume it is
  JUST_DIGITS = Regexp.new(/^\d+$/)

  # any garbage that just doesn't have any numbers
  NO_NUMBERS = Regexp.new(/^\D+$/)

  # someone exported a big num from excel, e.g. 1.1e+567
  EXPONENTIAL = Regexp.new(/\d[Ee]\+?\d/)

  # 55NEW55
  DIGIT_MIX = Regexp.new(/^\d+\D/)

  # for capturing the numeric part
  NUMERIC_PART = Regexp.new(/(\d+)/)

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

  STATUS    = Regexp.new(/CH|LM|WD/)
  CONDITION = Regexp.new(/BRT/)
  
  # Given a string, determines which valid ocns are in it,
  # and returns them as an array of Integers.
  def self.ocn(str)
    output = []
    str.strip!
    candidates = str.split(SPLIT_DELIM)

    # DO WHILE MAYBE COMEFROM reject_reason
    candidates.each do |candidate|
      catch(:rejected) do
        numeric_part = capture_numeric(candidate)
        candidate.strip!

        # Try to find a reason to reject the candidate ocn
        # Any time reject_reason triggers, go ^^ to the catch.
        candidate.nil? &&
          reject_reason("ocn is nil", "")

        candidate.empty? &&
          reject_reason("ocn is empty", "")

        EXPONENTIAL.match?(candidate) &&
          reject_reason("ocn is in exponential format", candidate)

        DIGIT_MIX.match?(candidate) &&
          reject_reason("ocn is mix of digits and non-digits", candidate)

        # Check prefixes, with / without parens
        if PAREN_PREFIX.match(candidate) then
          paren_expr = Regexp.last_match(0)
          OK_PAREN_PREFIX.match?(paren_expr) ||
            reject_reason("ocn has an invalid paren prefix", candidate)
        elsif PREFIX.match(candidate) then
          prefix_expr = Regexp.last_match(0)
          OK_PREFIX.match?(prefix_expr) ||
            reject_reason("ocn has an invalid prefix", candidate)
        end

        # As far as the numeric part goes, the only thing we can say
        # about it is that it should be smaller than the current max ocn.
        numeric_part > CURRENT_MAX_OCN &&
          reject_reason("number is too large for an ocn", numeric_part)

        numeric_part == 0 &&
          reject_reason("ocn is zero", candidate)
        
        # If we made it this far, we assume candidate is OK.
        output << numeric_part
      end
    end

    # TODO? Resolve ocns and return uniq resolved?
    output.uniq!
    return output
  end

  def self.status(str)
    output = []
    STATUS.match(str) &&
      output << Regexp.last_match(0)

    return output
  end

  def self.condition(str)
    output = []
    CONDITION.match(str) &&
      output << Regexp.last_match(0)

    return output
  end

  def self.reject_reason(reason, val)
    warn [reason, val].join(":")
    throw :rejected
  end

  def self.capture_numeric(str)
    md = str.match(NUMERIC_PART)
    if !md.nil? then
      return md[0].to_i
    else
      reject_reason("could not extract numeric part", str)
    end
  end

end
