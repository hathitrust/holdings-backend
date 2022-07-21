# frozen_string_literal: true

require "scrub/common"
require "scrub/max_ocn"

# Check whether a string is a possible OCN.
# cand = Scrub::OcnCandidate.new(str)
# if cand.valid?
#   valid_ocn = cand.numeric_part
# end

module Scrub
  class OcnCandidate < Scrub::Common
    attr_reader :candidate, :numeric_part

    def initialize(str)
      @candidate = str
      @numeric_part = nil
      @valid = nil
      validate
    end

    def validate
      @valid = false
      return if is_nil?
      return if is_empty?
      return if is_exponential?
      return if is_digit_mix?
      return unless is_ok_prefix?
      capture_numeric
      return if numeric_too_large?
      return if numeric_zero?
      @valid = true
    end

    def valid?
      @valid
    end

    def is_nil?
      if @candidate.nil?
        count_x("ocn rejected: ocn is nil")
      end
    end

    def is_empty?
      if @candidate.empty?
        count_x("ocn rejected: ocn is empty")
      end
    end

    def is_exponential?
      if EXPONENTIAL.match?(@candidate)
        count_x("ocn rejected: is in exponential format", @candidate)
      end
    end

    def is_digit_mix?
      if DIGIT_MIX.match?(@candidate)
        count_x("ocn rejected: is mix of digits and non-digits", @candidate)
      end
    end

    def is_ok_prefix?
      # Check prefixes, w/wo parens
      if PAREN_PREFIX.match(@candidate)
        paren_expr = Regexp.last_match(0)
        count_x("ocn_paren #{paren_expr}")
        unless OK_PAREN_PREFIX.match?(paren_expr)
          count_x("ocn rejected: invalid paren prefix", @candidate)
          return false
        end
      elsif PREFIX.match(@candidate)
        prefix_expr = Regexp.last_match(0)
        count_x("ocn_prefix #{paren_expr}")
        unless OK_PREFIX.match?(prefix_expr)
          count_x("ocn rejected: invalid prefix", @candidate)
          return false
        end
      end

      true
    end

    def numeric_too_large?
      if @numeric_part > Scrub::MaxOcn.new.current_max_ocn
        count_x("ocn rejected: too large for an ocn", @numeric_part)
      end
    end

    def numeric_zero?
      if @numeric_part.zero?
        count_x("ocn rejected: numeric part is zero", @numeric_part)
      end
    end

    def capture_numeric
      md = @candidate.match(NUMERIC_PART)
      @numeric_part = md[0].to_i
    end
  end
end
