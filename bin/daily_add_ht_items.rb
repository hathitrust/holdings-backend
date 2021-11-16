#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "loader/hathifile_manager"
require "utils/multi_logger"

def setup_logger
  # log to Slack in addition to default logger
  default_logger = Services.logger

  Services.register(:logger) do
    Utils::MultiLogger.new(default_logger, Logger.new(Services.slack_writer, level: Logger::INFO))
  end
end

def main
  setup_logger
  Services.mongo!
  Loader::HathifileManager.new.try_load
end

main if __FILE__ == $PROGRAM_NAME
