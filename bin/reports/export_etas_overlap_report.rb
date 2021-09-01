#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "../..", "lib"))
require "services"
require "settings"
require "bundler/setup"
require "report/etas_member_overlap_report"

Services.mongo!

if __FILE__ == $PROGRAM_NAME
  # optional
  org = ARGV.shift
  rpt = Report::EtasMemberOverlapReport.new(org)
  rpt.run
end
