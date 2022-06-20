# frozen_string_literal: true

require "scrub/common"

module Scrub
  class LocalId < Scrub::Common
    # Given a string, checks if there are any valid-looking local_ids
    # and returns it/them as an array of strings.
    def initialize(str)
      @output = []

      if str.nil?
        raise ArgumentError, "local_id is nil"
      end

      candidates = str.strip.split(LOCAL_ID_SPLIT_DELIM)

      if candidates.size > 1
        count_x("#{candidates.size} candidates in one local_id field")
        # TODO: maybe throw something??
      end

      candidates.each do |candidate|
        next if too_long?(candidate)
        @output << candidate
      end
    end

    def value
      @output.uniq
    end

    def too_long?(candidate)
      if candidate.length > LOCAL_ID_MAX_LEN
        count_x("local_id rejected, too long", candidate.length, "max #{LOCAL_ID_MAX_LEN}")
      end
    end
  end
end
