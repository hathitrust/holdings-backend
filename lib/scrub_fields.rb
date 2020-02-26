# frozen_string_literal: true

class ScrubFields

  # "444; 555; 666" -> %w[444,555,666]
  SPLIT_DELIM = Regexp.new(/[,:;\|\/ ]+/)

  # ocn555
  PREFIX = Regexp.new(/^\D+\d+/)

  # (ocolc)555
  PAREN_PREFIX = Regexp.new(/^\(.+?\)\d+/)

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
  @@current_max_ocn = nil
  max_ocn = `bash #{__dir__}/get_max_ocn.sh`.split("\n").last
  if !max_ocn.nil? then
    max_ocn.strip!
    if JUST_DIGITS.match?(max_ocn) then
      @@current_max_ocn  = max_ocn.to_i
    end
  end

  if @@current_max_ocn.nil? then
    raise "failed to set @@current_max_ocn"
  end

  if @@current_max_ocn.class != Integer then
    raise "failed to CORRECTLY set @@current_max_ocn"
  end

  # Given a string, determines which valid ocns are in it,
  # and returns them as an array of Integers.
  def self.ocn(str)
    output = []
    str.strip!
    candidates = str.split(SPLIT_DELIM)

    # DO WHILE MAYBE COMEFROM reject_reason
    catch(:rejected) do
      candidates.each do |candidate|
        numeric_part = self.capture_numeric(candidate)
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

        numeric_part > @@current_max_ocn &&
          reject_reason("number is too large for an ocn", numeric_part)

        # If we made it this far, we assume candidate is OK.
        output << numeric_part
      end
    end

    output.uniq!
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
