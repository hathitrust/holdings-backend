#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates ETAS overlap reports for a given organization or all

require "services"
require "settings"
require "reports/etas_organization_overlap_report"

def main
  Services.mongo!

  # optional
  org = ARGV.shift
  rpt = Reports::EtasOrganizationOverlapReport.new(org)
  rpt.run
  rpt.move_reports_to_remote
end

main if $PROGRAM_NAME == __FILE__
