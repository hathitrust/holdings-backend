# frozen_string_literal: true

require "scrub/common"

module Scrub
  class Issn < Scrub::Common
    def initialize(str)
      if str.nil?
        raise ArgumentError, "issn is nil"
      end

      candidates = str.split(ISSN_DELIM)
      @ok_issns = []

      candidates.each do |candidate|
        next unless issn?(candidate)
        @ok_issns << candidate
      end
    end

    def value
      [@ok_issns.join(";")]
    end

    def issn?(candidate)
      unless ISSN.match?(candidate)
        count_x("ISSN rejected (#{candidate}), does not match pattern.")
        return false
      end
      true
    end
  end
end
