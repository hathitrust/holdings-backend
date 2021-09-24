#!/usr/bin/env ruby
# frozen_string_literal: true

require "compare_cluster"

Services.mongo!

ARGF.each_line do |line|
  CompareCluster.new(line.strip).compare
end
