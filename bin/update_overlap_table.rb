#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "cluster"
require "overlap/cluster_overlap" # not used?
require "logger"
require "services"
require "utils/waypoint"
require "date"
require "overlap/overlap_table_update"

Services.mongo!

if __FILE__ == $PROGRAM_NAME

  # Default: Now - 36 hours
  cutoff_date = Date.today - 1.5

  unless ARGV.empty?
    cutoff_date = Date.parse(ARGV.shift)
  end

  Overlap::OverlapTableUpdate.new(cutoff_date).run
end
