#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "cluster"
require "logger"
require "services"
require "date"
require "overlap/overlap_table_update"

def main
  # Default: Now - 36 hours
  cutoff_date = Date.today - 1.5

  unless ARGV.empty?
    cutoff_date = Date.parse(ARGV.shift)
  end

  Overlap::OverlapTableUpdate.new(cutoff_date).run
end

main if __FILE__ == $PROGRAM_NAME
