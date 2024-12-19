#!/usr/bin/env ruby
# frozen_string_literal: true

require "compare_cluster"

def main
  ARGF.each_line do |line|
    CompareCluster.new(line.strip).compare
  end
end

main if __FILE__ == $PROGRAM_NAME
