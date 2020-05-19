#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster_ocn_resolution"
require "ocn_resolution"

Mongoid.load!("mongoid.yml", :test)

File.open(ARGV.shift).each do |line|
  (deprecated, resolved) = line.split.map(&:to_i)
  r = OCNResolution.new(deprecated: deprecated, resolved: resolved)
  c = ClusterOCNResolution.new(r).cluster
  c.save
  count += 1

  if (count % 10_000).zero?
    puts "#{Time.now}: #{count} records loaded"
  end
end
