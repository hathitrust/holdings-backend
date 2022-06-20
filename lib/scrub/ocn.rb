# frozen_string_literal: true

require "scrub/common"

module Scrub
  class Ocn < Scrub::Common
    # Take a string, presumed to be one or more OCNs, and get the actual OCNs out as numbers.
    def initialize(str)
      @ok_ocns = []

      if str.nil?
        raise ArgumentError, "ocn is nil"
      end

      count_x(:rec_with_ocn)
      candidates = str.split(OCN_SPLIT_DELIM).map(&:strip).map { |c| Scrub::OcnCandidate.new(c) }

      # TODO: maybe we don't care about this?
      # I've found it to be a good indicator that the record wasn't
      # exported properly, but there are legit cases of this I guess.
      if candidates.size > MAX_NUM_ITEMS
        count_x("A lot of ocns (#{candidates.size}) in ocn", str)
      end

      count_x(:multi_ocn_record) if candidates.size > 1

      candidates.select(&:valid?).each do |candidate|
        @ok_ocns << candidate.numeric_part
      end
    end

    def value
      @ok_ocns.uniq
    end
  end
end
