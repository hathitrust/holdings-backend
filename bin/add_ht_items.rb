#!/usr/bin/env ruby
# frozen_string_literal: true

require "loader/file_loader"
require "loader/ht_item_loader"
require "services"

Services.mongo!
Services.logger.info "Updating HT Items."

if __FILE__ == $PROGRAM_NAME
  filename = ARGV[0]
  Loader::FileLoader.new(batch_loader: Loader::HtItemLoader.new).load(filename)
end
