class ScrubFields

  # "444; 555; 666" -> %w[444,555,666]
  @@split_delim = Regexp.new(/[,:;\|\/ ]+/)

  # ocn555
  @@prefix = Regexp.new(/^\D+\d+/)
  
  # (ocolc)555 
  @@paren_prefix = Regexp.new(/^\(.+?\)\d+/)

  # No prefix, just "555", could be an ocn so we assume it is
  @@just_digits = Regexp.new(/^\d+$/)

  # any garbage that just doesn't have any numbers
  @@no_numbers = Regexp.new(/^\D+$/)

  # someone exported a big num from excel, e.g. 1.1e+567
  @@exponential = Regexp.new(/\d[Ee]\+?\d/)

  # 55NEW55
  @@digit_mix = Regexp.new(/^\d+\D/)

  # for capturing the numeric part
  @@numeric_part = Regexp.new(/(\d+)/)
  
  # Get current max oclc
  # TODO: maybe rewrite this in ruby for testability / less crappiness
  @@current_max_ocn = nil
  max_ocn = `bash #{__dir__}/get_max_ocn.sh`.split("\n").last
  if !max_ocn.nil? then
    max_ocn.strip!
    if max_ocn =~ @@just_digits then
      @@current_max_ocn  = max_ocn.to_i
    end
  end

  if @@current_max_ocn.nil? then
    raise "failed to set @@current_max_ocn"
  end

  if @@current_max_ocn.class != Integer then
    raise "failed to CORRECTLY set @@current_max_ocn" 
  end
  
  def self.ocn (str)
    output = []
    str.strip!
    candidates = str.split(@@split_delim)

    # DO WHILE MAYBE COMEFROM reject_reason
    catch (:rejected) do
      candidates.each do |candidate|
        numeric_part = self.capture_numeric(candidate)
        candidate.strip!

        # Try to find a reason to reject the candidate ocn
        case
        when candidate.nil?
          self.reject_reason("ocn is nil", "")
        when candidate.empty?
          self.reject_reason("ocn is empty", candidate)
        when candidate =~ @@exponential
          self.reject_reason("ocn is in exponential format", candidate)
        when candidate =~ @@digit_mix
          self.reject_reason("ocn is mix of digits and non-digits", candidate)
        when numeric_part > @@current_max_ocn
          self.reject_reason("number is too large for an ocn", numeric_part)
        else
          output << numeric_part
        end
      end
    end
    
    output.uniq!
    return output
  end

  def self.reject_reason (reason, val)
    STDERR.puts [reason, val].join(":")
    throw :rejected
  end

  def self.capture_numeric (str)
    md = str.match(@@numeric_part)
    if !md.nil? then
      return md[0].to_i
    else
      self.reject_reason("could not extract numeric part", str)
    end
  end
  
end
