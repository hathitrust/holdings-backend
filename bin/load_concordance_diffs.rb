#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "services"
require "ocn_concordance_diffs"
require "utils/multi_logger"

Services.mongo!

# log to Slack in addition to default logger
default_logger = Services.logger

date_to_load = ARGV[0]

raise "Usage: #{$PROGRAM_NAME} YYYY-mm-dd" unless date_to_load

Services.register(:logger) do
  Utils::MultiLogger.new(default_logger, Logger.new(Services.slack_writer, level: Logger::INFO))
end

OCNConcordanceDiffs.new(date_to_load).try_load
