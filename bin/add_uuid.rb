#!/usr/bin/env ruby
# frozen_string_literal: true

# Appends a UUID to each incoming holdings line

require "securerandom"

ARGF.each do |line|
  if /^OCN\tBIB/.match?(line)
    puts [line.strip, "UUID"].join("\t")
  else
    puts [line.strip, SecureRandom.uuid].join("\t")
  end
end
