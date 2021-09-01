#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "../..", "lib"))
require "bundler/setup"
require "zinzout"
require "report/overlap_report"

Mongoid.load!("mongoid.yml", :test)

BATCH_SIZE = 10_000

if __FILE__ == $PROGRAM_NAME
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
  Report::OverlapReport.new(org, BATCH_SIZE).run
end
