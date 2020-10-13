#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "file_loader"
require "ht_item_loader"
require "services"

Services.mongo!
Services.logger.info "Updating HT Items."

filename = ARGV[0]
FileLoader.new(batch_loader: HtItemLoader.new).load(filename)
