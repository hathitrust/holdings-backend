# frozen_string_literal: true

require "zlib"

# Concordance validation.
# Takes a file with <variant ocn> <tab> <canonical ocn>, checks that its ok.
# Prints only <variant> to <canonical ocn>
module ConcordanceValidation
  # A Concordance.
  # Hash maps of variant to canonical and canonical to variant.
  # Associated validation methods.
  class Concordance
    attr_accessor :variant_to_canonical, :canonical_to_variant, :infile

    def initialize(infile)
      @infile = infile
      Concordance.numbers_tab_numbers(infile)
      @variant_to_canonical = Hash.new { |h, k| h[k] = [] }
      @canonical_to_variant = Hash.new { |h, k| h[k] = [] }
      file_handler.open(infile).each do |line|
        # first pass
        variant, canonical = line.chomp.split("\t")
        variant_to_canonical[variant.to_i] << canonical.to_i if variant != canonical
        canonical_to_variant[canonical.to_i] << variant.to_i if variant != canonical
      end
      @variant_to_canonical.default_proc = ->(_, _) {}
      @canonical_to_variant.default_proc = ->(_, _) {}
    end

    def file_handler
      if /\.gz$/.match?(@infile)
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
      raise "Cycles: #{in_edges.keys.sort.join(", ")}" if in_edges.keys.any?
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
        out_edges[ocn] = @variant_to_canonical[ocn].clone if @variant_to_canonical[ocn]&.any?
        @variant_to_canonical[ocn]&.each do |to_ocn|
          ocns_to_check << to_ocn unless ocns_checked.include? to_ocn
        end
        in_edges[ocn] = @canonical_to_variant[ocn].clone if @canonical_to_variant[ocn]&.any?
        @canonical_to_variant[ocn]&.each do |from_ocn|
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
    def canonical_ocn?(ocn)
      !@variant_to_canonical.key? ocn
    end

    # Find the terminal ocn for a given ocn
    # Will fail endlessly if there are cycles.
    def canonical_ocn(ocn)
      canonical = @variant_to_canonical[ocn].clone
      loop do
        # only one ocn and it is a terminal
        return canonical.first if (canonical.count == 1) && canonical_ocn?(canonical.first)

        # multiple ocns, but they are all terminal
        if canonical.all? { |o| canonical_ocn? o }
          raise "OCN:#{ocn} resolves to multiple ocns: #{canonical.join(", ")}"
        end

        # find more ocns in the chain
        canonical.each do |o|
          # it is not terminal so we replace with the ocns it resolves to
          if @variant_to_canonical.key? o
            canonical.map! { |x| (x == o) ? @variant_to_canonical[o] : x }.flatten!
          end
        end
        canonical.uniq!
      end
    end

    # Confirm file is of format:
    # <numbers> <tab> <numbers>
    #
    # @param infile file name for the concordance
    # @return raise error if invalid
    def self.numbers_tab_numbers(infile)
      grepper = infile.match?(/\.gz$/) ? "zgrep" : "grep"
      line_count = `#{grepper} -cvP '^[0-9]+\t[0-9]+$' #{infile}`
      raise "Invalid format. #{line_count.to_i} line(s) are malformed." unless line_count.to_i.zero?
    end
  end
end
