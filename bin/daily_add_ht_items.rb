#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "services"
require "hathifile_manager"

Services.mongo!

HathifileManager.new.try_load
