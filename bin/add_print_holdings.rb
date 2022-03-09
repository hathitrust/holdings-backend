#!/usr/bin/env ruby
# frozen_string_literal: true

require "loader/file_loader"
require "loader/holding_loader"
require "services"

def main(filename)
  Services.mongo!

  Services.logger.info "Adding Print Holdings from #{filename}."
  holding_loader = Loader::HoldingLoader.for(filename)
  Loader::FileLoader.new(batch_loader: holding_loader).load(filename, skip_header_match: /\A\s*OCN/)
  holding_loader.final_line
end

main(ARGV[0]) if __FILE__ == $PROGRAM_NAME
