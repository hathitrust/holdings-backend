#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster"
require "holding"
require 'json'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.on("-m", "--member MEMBER", "Member whose holdings are being added") do |m|
    options[:member] = m
  end
>>>>>>> 693d94f... Basic add and update holdings bins
  opts.on("-d", "--delete", "Delete member holdings before adding") do |d|
    options[:delete] = d
  end
  opts.on("-h", "--holdings HOLDINGS", "Holdings file") do |h|
    options[:holdings] = h
  end
end.parse!
raise OptionParser::MissingArgument if options[:holdings].nil?
raise OptionParser::MissingArgument if options[:member].nil?

# If a full replace of a member's holdings
if options[:delete]
  Cluster.where("holdings.organization": options[:member]).each do |c|
    c.holdings.each do |h|
      h.delete if h.organization == options[:member]
    end
  end
end

File.open(options[:holdings]) do |line|
  holding = JSON.parse(line)
  Holding.add(holding)

  count += 1

  if (count % 10_000).zero?
    puts "#{Time.now}: #{count} records loaded"
  end
end
