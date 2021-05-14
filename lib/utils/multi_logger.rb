# frozen_string_literal: true

require "logger"

module Utils
  # Logger replacement for forwarding message to multiple loggers.
  #
  # Note that the configured severity level has no effect on MultiLogger; rather,
  # all messages are forwarded to each configured logger, which can have its own
  # configured severity level, formatter, etc.
  #
  # Usage:
  #
  # logger = MultiLogger.new(Logger.new(...), Logger.new(...))
  #
  class MultiLogger < Logger

    def initialize(*loggers)
      @loggers = loggers

      super(nil)
    end

    def add(severity, message = nil, progname = nil, &block)
      @loggers.each do |logger|
        logger.add(severity, message, progname, &block)
      end
    end
  end
end
