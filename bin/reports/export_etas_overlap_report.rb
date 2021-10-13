#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "settings"
require "reports/etas_organization_overlap_report"

Services.mongo!

if __FILE__ == $PROGRAM_NAME
  # optional
  org = ARGV.shift
  rpt = Reports::EtasOrganizationOverlapReport.new(org)
  rpt.run
end
