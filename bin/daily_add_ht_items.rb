#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "loader/hathifile_manager"
require "utils/multi_logger"

Services.mongo!

# log to Slack in addition to default logger
default_logger = Services.logger

Services.register(:logger) do
  Utils::MultiLogger.new(default_logger, Logger.new(Services.slack_writer, level: Logger::INFO))
end

if __FILE__ == $PROGRAM_NAME
  Loader::HathifileManager.new.try_load
end
