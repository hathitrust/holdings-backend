#!/usr/bin/env ruby
# frozen_string_literal: true

# Appends a UUID to each incoming holdings line

require "securerandom"

def main
  ARGF.each do |line|
    if /^OCN\tBIB/.match?(line)
      puts [line.chomp, "UUID"].join("\t")
    else
      puts [line.chomp, SecureRandom.uuid].join("\t")
    end
  end
end

main if __FILE__ == $PROGRAM_NAME
