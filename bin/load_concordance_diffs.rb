#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "ocn_concordance_diffs"
require "utils/multi_logger"
require "date"

def setup_logger
  # log to Slack in addition to default logger
  default_logger = Services.logger

  Services.register(:logger) do
    Utils::MultiLogger.new(default_logger, Logger.new(Services.slack_writer, level: Logger::INFO))
  end
end

def main
  Services.mongo!

  setup_logger

  date_to_load = ARGV[0]

  raise "Usage: #{$PROGRAM_NAME} YYYY-mm-dd" unless date_to_load

  OCNConcordanceDiffs.new(Date.parse(date_to_load)).load
end

main if $PROGRAM_NAME == __FILE__
