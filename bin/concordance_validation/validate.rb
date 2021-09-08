#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "../..", "lib"))
require "settings"
require "concordance_validation/concordance"

if $PROGRAM_NAME == __FILE__
  fin = ARGV.shift
  fout = ARGV.shift
  log = File.open("#{fout}.log", 'w')
  fout = File.open(fout, 'w')

  c = ConcordanceValidation::Concordance.new(fin)
  c.raw_to_resolved.each_key do |raw|
    next if c.raw_to_resolved[raw].count.zero?

    begin
      sub = c.compile_sub_graph(raw)
      c.detect_cycles(*sub)
    rescue StandardError => e
      log.puts e
      log.puts "Cycles:#{(sub[0].keys + sub[1].keys).flatten.uniq.join(', ')}"
      next
    end
    begin
      # checks for multiple terminal ocns
      terminal = c.terminal_ocn(raw)
    rescue StandardError => e
      log.puts e
      next
    end

    fout.puts [raw, c.terminal_ocn(raw)].join("\t")
  end
end
