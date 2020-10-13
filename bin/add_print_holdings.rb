#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "file_loader"
require "holding_loader"
require "services"

Services.mongo!

update = ARGV[0] == "-u"
if update
  filename = ARGV[1]
  Services.logger.info "Updating Print Holdings."
else
  filename = ARGV[0]
  Services.logger.info "Adding Print Holdings."
end

holding_loader = HoldingLoader.new(update: update)

FileLoader.new(batch_loader: holding_loader).load(filename)

holding_loader.finalize
