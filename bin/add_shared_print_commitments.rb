#!/usr/bin/env ruby
# frozen_string_literal: true

require "loader/file_loader"
require "loader/shared_print_loader"
require "services"

Services.mongo!
Services.logger.info "Updating Shared Print Commitments."

if __FILE__ == $PROGRAM_NAME
  filename = ARGV[0]
  Loader::FileLoader.new(batch_loader: Loader::SharedPrintLoader.new).load(filename)
end
