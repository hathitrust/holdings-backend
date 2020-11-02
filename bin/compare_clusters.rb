#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "compare_cluster"

Services.mongo!

ARGF.each_line do |line|
  CompareCluster.new(line.strip).compare
end
