# frozen_string_literal: true

require 'zlib'
require 'pp'

# Concordance validation.
# Takes a file with <raw ocn> <tab> <resolved ocn>, checks that its ok.
# Prints only <raw> to <terminal ocn>
module ConcordanceValidation
  # A Concordance.
  # Hash maps of raw to resolved and resolved to raw.
  # Associated validation methods.
  class Concordance
    attr_accessor :raw_to_resolved, :resolved_to_raw, :infile

    def initialize(infile)
      @infile = infile
      Concordance.numbers_tab_numbers(infile)
      @raw_to_resolved = Hash.new { |h, k| h[k] = [] }
      @resolved_to_raw = Hash.new { |h, k| h[k] = [] }
      file_handler.open(infile).each do |line|
        # first pass
        raw, resolved = line.chomp.split("\t")
        raw_to_resolved[raw.to_i] << resolved.to_i if raw != resolved
        resolved_to_raw[resolved.to_i] << raw.to_i if raw != resolved
      end
      @raw_to_resolved.default_proc = ->(_,_) { nil }
      @resolved_to_raw.default_proc = ->(_,_) { nil }
    end

    def file_handler
      if @infile =~ /\.gz$/
        Zlib::GzipReader
      else
        File
      end
    end

    # Kahn's algorithm for detecting cycles in a graph
    #
    # @param out_edges, in_edges from unresolved to resolved and vice versa
    # @return raise an error if a cycle is found
    def detect_cycles(out_edges, in_edges)
      # build a list of start nodes, nodes without an incoming edge
      start_nodes = []
      out_edges.each_key do |o|
        start_nodes << o unless in_edges.key? o
      end

      while start_nodes.count.positive?
        node_n = start_nodes.shift
        next unless out_edges.key? node_n

        out_edges[node_n].each do |node_m|
          in_edges[node_m].delete(node_n)
          if in_edges[node_m].count.zero?
            in_edges.delete(node_m)
            start_nodes << node_m
          end
        end
      end
      raise "Cycles: #{in_edges.keys.sort.join(', ')}" if in_edges.keys.any?
    end

    # Given an ocn, compile all related edges
    #
    # @param src_ocn
    # @return [out_edges, in_edges]
    def compile_sub_graph(src_ocn)
      out_edges = {}
      in_edges = {}
      ocns_to_check = [src_ocn]
      ocns_checked = []
      while ocns_to_check.any?
        ocn = ocns_to_check.pop
        out_edges[ocn] = @raw_to_resolved[ocn].clone if @raw_to_resolved[ocn]&.any?
        @raw_to_resolved[ocn]&.each do |to_ocn|
          ocns_to_check << to_ocn unless ocns_checked.include? to_ocn
        end
        in_edges[ocn] = @resolved_to_raw[ocn].clone if @resolved_to_raw[ocn]&.any?
        @resolved_to_raw[ocn]&.each do |from_ocn|
          ocns_to_check << from_ocn unless ocns_checked.include? from_ocn
        end
        ocns_checked << ocn
      end
      [out_edges, in_edges]
    end

    # Is this a terminal ocn
    #
    # @param ocn to check
    # @return true if it doesn't resolve to something
    def terminal_ocn?(ocn)
      @raw_to_resolved[ocn].nil? || @raw_to_resolved[ocn].count.zero?
    end

    # Find the terminal ocn for a given ocn
    # Will fail endlessly if there are cycles.
    def terminal_ocn(ocn)
      resolved = @raw_to_resolved[ocn].clone
      loop do
        # only one ocn and it is a terminal
        return resolved.first if (resolved.count == 1) && terminal_ocn?(resolved.first)

        # multiple ocns, but they are all terminal
        raise "OCN:#{ocn} resolves to multiple ocns: #{resolved.join(', ')}" if resolved.all? { |o| terminal_ocn? o }

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
    #
    # @param infile file name for the concordance
    # @return raise error if invalid
    def self.numbers_tab_numbers(infile)
      grepper = infile.match?(/\.gz$/) ? 'zgrep' : 'grep'
      line_count = `#{grepper} -cvP '^[0-9]+\t[0-9]+$' #{infile}`
      raise "Invalid format. #{line_count.to_i} line(s) are malformed." unless line_count.to_i.zero?
    end
  end
end

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
