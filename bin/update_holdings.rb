#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "json"
require "holding"

holdings = ARGV.shift

File.open(holdings).each do |line|
  holding = JSON.parse(line)
  Holding.update(holding)

  count += 1

  if (count % 10_000).zero?
    puts "#{Time.now}: #{count} records loaded"
  end
end
