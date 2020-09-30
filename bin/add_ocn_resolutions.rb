#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "file_loader"
require "ocn_resolution_loader"
require "services"

Services.mongo!
Services.logger.info "Adding OCN Resolutions"

filename = ARGV[0]
FileLoader.new(batch_loader: OCNResolutionLoader.new).load(filename)
