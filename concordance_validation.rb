# frozen_string_literal: true

require 'zlib'

# Concordance validation.
# Takes a file with <raw ocn> <tab> <resolved ocn>, checks that its ok.
# Prints only <raw> to <terminal ocn>
module ConcordanceValidation
  # A Concordance.
  # Hash maps of raw to resolved and resolved to raw.
  # Associated validation methods.
  class Concordance
    attr_accessor :raw_to_resolved
    attr_writer :resolved_to_raw
    attr_accessor :infile

    def initialize(infile, validate: false)
      @infile = infile
      Concordance.numbers_tab_numbers(infile) if validate
      @raw_to_resolved = Hash.new { |h, k| h[k] = [] }
      file_handler.open(infile).each do |line|
        # first pass
        raw, resolved = line.chomp.split("\t")
        raw_to_resolved[raw.to_i] << resolved.to_i if raw != resolved
      end
      detect_cycles if validate
    end

    def file_handler
      if @infile =~ /\.gz$/
        Zlib::GzipReader
      else
        File
      end
    end

    # Build a reverse index for resolved ocns to raw ocns.
    def resolved_to_raw
      unless @resolved_to_raw
        @resolved_to_raw = Hash.new { |h, k| h[k] = [] }
        @raw_to_resolved.each do |raw, resolved_ocns|
          resolved_ocns.each do  |resolved_ocn|
            @resolved_to_raw[resolved_ocn] << raw
          end
        end
      end
      @resolved_to_raw
    end

    # Kahn's algorithm for detecting cycles in a graph
    def detect_cycles
      sorted = []
      # build a list of start nodes, nodes without an incoming edge
      start_nodes = []
      @raw_to_resolved.keys.each do |o|
        start_nodes << o unless resolved_to_raw.keys.include? o
      end

      while start_nodes.count.positive?
        node_n = start_nodes.shift
        sorted << node_n
        @raw_to_resolved[node_n].each do |node_m|
          resolved_to_raw[node_m].delete(node_n)
          if resolved_to_raw[node_m].count.zero?
            resolved_to_raw.delete(node_m)
            start_nodes << node_m
          end
        end
      end
      if resolved_to_raw.keys.any?
        raise "Cycles: #{resolved_to_raw.keys.sort.join(', ')}"
      end

      sorted.sort
    end

    # Is this a terminal ocn
    def terminal_ocn?(ocn)
      !(@raw_to_resolved.key? ocn)
    end

    # Find the terminal ocn for a given ocn
    # Will fail endlessly if there are cycles.
    def terminal_ocn(ocn)
      resolved = @raw_to_resolved[ocn]
      loop do
        # only one ocn and it is a terminal
        if (resolved.count == 1) && terminal_ocn?(resolved.first)
          return resolved.first
        end

        # multiple ocns, but they are all terminal
        if resolved.all? { |o| terminal_ocn? o }
          raise "OCN:#{ocn} resolves to multiple ocns: #{resolved.join(', ')}"
        end

        # find more ocns in the chain
        resolved.each do |o|
          # it is not terminal so we replace with the ocns it resolves to
          if @raw_to_resolved.key? o
            resolved.map! { |x| x == o ? @raw_to_resolved[o] : x }.flatten!
          end
        end
        resolved.uniq!
      end
    end

    # Confirm file is of format:
    # <numbers> <tab> <numbers>
    def self.numbers_tab_numbers(infile)
      grepper = infile.match?(/\.gz$/) ? 'zgrep' : 'grep'
      line_count = `#{grepper} -cvP '^[0-9]+\t[0-9]+$' #{infile}`
      unless line_count.to_i.zero?
        raise "Invalid format. #{line_count.to_i} line(s) are malformed."
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  fin = ARGV.shift
  c = ConcordanceValidation::Concordance.new(fin, validate: true)
  c.keys.each do |raw|
    puts [raw, c.terminal_ocn(raw)].join("\t")
  end
end
