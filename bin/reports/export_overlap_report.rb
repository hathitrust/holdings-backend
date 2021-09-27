#!/usr/bin/env ruby
# frozen_string_literal: true

require "zinzout"
require "reports/overlap_report"

BATCH_SIZE = 10_000

if __FILE__ == $PROGRAM_NAME
  Services.mongo!
  require "optparse"

  options = {}
  OptionParser.new do |opts|
    opts.on(
      "-f",
      "--full",
      "Produce overlaps for all matching clusters."
    ) do |f|
      options.full = f
    end
    opts.on("-o", "--organization", "Limit overlap records to a particular organization.") do |org|
      options.organization = org || ""
    end
  end

  org = ARGV.shift
  Reports::OverlapReport.new(org, BATCH_SIZE).run
end
