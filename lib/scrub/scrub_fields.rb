# frozen_string_literal: true

require "enum_chron_parser"
require "scrub/condition"
require "scrub/gov_doc"
require "scrub/issn"
require "scrub/local_id"
require "scrub/ocn"
require "scrub/status"
require "services"

module Scrub
  # This class knows how to extract and validate certain values
  # from a member submission file.
  class ScrubFields
    attr_reader :ec_parser

    def initialize
      @ec_parser = EnumChronParser.new
    end

    # Given a string, determines which valid ocns are in it,
    # and returns them as a uniq'd array of Integers.
    def ocn(str)
      Scrub::Ocn.new(str).value
    end

    def local_id(str)
      Scrub::LocalId.new(str).value
    end

    # Given a string, checks if there are any valid-looking issns,
    # Returns a bit of a mess...
    # ... a  single element array, where [0] is a ;-joined string.
    def issn(str)
      Scrub::Issn.new(str).value
    end

    # Given an enumchron str, returns an array with a norm'd enum and norm'd chron
    # The enumchron parser is ancient, murky & probably not the best.
    def enumchron(str)
      ec_parser.parse(str)
      [ec_parser.normalized_enum, ec_parser.normalized_chron]
    end

    # checks that the given string contains an ok status
    def status(str)
      Scrub::Status.new(str).value
    end

    # checks that the given string contains an ok condition
    def condition(str)
      Scrub::Condition.new(str).value
    end

    # checks that the given string contains an ok govdoc
    def govdoc(str)
      Scrub::GovDoc.new(str).value
    end
  end
end
