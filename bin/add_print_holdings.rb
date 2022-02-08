#!/usr/bin/env ruby
# frozen_string_literal: true

require "loader/file_loader"
require "loader/holding_loader"
require "services"

def main
  Services.mongo!

  filename = ARGV[0]
  Services.logger.info "Adding Print Holdings from #{filename}."
  holding_loader = Loader::HoldingLoader.for(filename)
  Loader::FileLoader.new(batch_loader: holding_loader).load(filename, skip_header_match: /\A\s*OCN/)
  holding_loader.final_line

  organization = holding_loader.instance_variable_get("@organization")
  rpt = Reports::EtasOrganizationOverlapReport.new(organization)
  rpt.run
  rpt.move_reports_to_remote
end

main if __FILE__ == $PROGRAM_NAME
