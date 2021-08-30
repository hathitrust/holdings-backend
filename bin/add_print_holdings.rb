#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "loader/file_loader"
require "loader/holding_loader"
require "services"

if __FILE__ == $PROGRAM_NAME
  Services.mongo!

  filename = ARGV[0]
  Services.logger.info "Adding Print Holdings from #{filename}."
  holding_loader = Loader::HoldingLoader.for(filename)
  Loader::FileLoader.new(batch_loader: holding_loader).load(filename, skip_header_match: /\A\s*OCN/)
  holding_loader.finalize
end
