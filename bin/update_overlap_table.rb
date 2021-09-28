#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "cluster"
require "cluster_overlap"
require "logger"
require "services"
require "utils/waypoint"
require "date"
require "overlap_table_update"

Services.mongo!

if __FILE__ == $PROGRAM_NAME

  # Default: Now - 36 hours
  cutoff_date = Date.today - 1.5

  unless ARGV.empty?
    cutoff_date = Date.parse(ARGV.shift)
  end

  update = OverlapTableUpdate.new(cutoff_date)
  update.run
  Services.logger.info "Num deletes: #{update.num_deletes}"
  Services.logger.info "Num adds: #{update.num_adds}"
end
