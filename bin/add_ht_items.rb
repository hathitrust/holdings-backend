#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "loader/file_loader"
require "loader/ht_item_loader"
require "services"

Services.mongo!
Services.logger.info "Updating HT Items."

if __FILE__ == $PROGRAM_NAME
  filename = ARGV[0]
  FileLoader.new(batch_loader: HtItemLoader.new).load(filename)
end
