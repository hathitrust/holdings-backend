#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "services"
require "hathifile_manager"
require "utils/multi_logger"

Services.mongo!

# log to Slack in addition to default logger
default_logger = Services.logger

Services.register(:logger) do
  Utils::MultiLogger.new(default_logger, Logger.new(Services.slack_writer, level: Logger::INFO))
end

HathifileManager.new.try_load
