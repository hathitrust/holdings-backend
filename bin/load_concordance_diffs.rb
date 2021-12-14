#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "ocn_concordance_diffs"
require "date"

def main
  Services.mongo!

  date_to_load = ARGV[0]

  raise "Usage: #{$PROGRAM_NAME} YYYY-mm-dd" unless date_to_load

  OCNConcordanceDiffs.new(Date.parse(date_to_load)).load
end

main if $PROGRAM_NAME == __FILE__
