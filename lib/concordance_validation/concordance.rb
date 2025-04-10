# frozen_string_literal: true

require "sqlite3"
require "zlib"

# Concordance validation.
# Takes a file with <variant ocn> <tab> <canonical ocn>, checks that its ok.
# Prints only <variant> to <canonical ocn>
module ConcordanceValidation
  # A Concordance.
  # Uses a temporary (for now) Sqlite database with a single table `concordance`
  # containing variant <-> canonical mappings under validation.
  #
  # Creates two derivative files
  # - concordance.sqlite
  # - <concordance_file>_dedupe.txt
  #
  # These are written to Settings.concordance_database_path which may be a temporary
  # directory. For development this should be set to something persistent if testing
  # a full workflow.
  class Concordance
    attr_reader :db, :concordance_file

    CREATE_TABLE_SQL = <<~SQL
      CREATE TABLE IF NOT EXISTS concordance(
        variant INTEGER NOT NULL,
        canonical INTEGER NOT NULL
      )
    SQL

    CREATE_VARIANT_INDEX_SQL = <<~SQL
      CREATE INDEX IF NOT EXISTS variant_idx ON concordance (variant)
    SQL

    CREATE_CANONICAL_INDEX_SQL = <<~SQL
      CREATE INDEX IF NOT EXISTS canonical_idx ON concordance (canonical)
    SQL

    TEST_MEMORY_DB = false

    # Match lines that are exactly X<tab>X and delete them.
    # The literal regex that get passed to sed is /^\(.*\)\t\(\1\)$/d
    SED_DEDUPE_REGEX = "/^\\(.*\\)\\t\\(\\1\\)$/d"

    def initialize(concordance_file)
      @concordance_file = concordance_file
      @db_dir = Settings.concordance_database_path
      FileUtils.mkdir_p @db_dir
      @db_file = File.join(@db_dir, "concordance.sqlite")
      @db = SQLite3::Database.open @db_file

      Services.logger.info "creating table at #{@db_file}..."
      @db.execute CREATE_TABLE_SQL

      dedupe_concordance_file
      populate_database

      # If we have enough memory to keep from thrashing then this may enhance performance.
      # For now this is too much for desktop/Docker when running a real concordance
      # so leave it disabled until we can re-evaluate.
      if TEST_MEMORY_DB
        mem_db = SQLite3::Database.new ":memory:"
        # Copy the source DB into the the memory DB
        Services.logger.info "creating in-memory table..."
        backup = SQLite3::Backup.new(mem_db, "main", @db, "main")
        backup.step(-1)
        backup.finish
        @db.close
        @db = mem_db
      end
    end

    def populate_database
      count = @db.execute("SELECT COUNT(*) FROM concordance")[0][0]
      if count.zero?
        Services.logger.info "importing data from #{@deduped_concordance_file}..."
        sqlite3_command = <<~END
          sqlite3 "#{@db_file}" << EOF
          .mode tabs
          .import "#{@deduped_concordance_file}" "concordance"
          EOF
        END
        system(sqlite3_command, exception: true)
        Services.logger.info "creating indexes..."
        @db.execute CREATE_VARIANT_INDEX_SQL
        @db.execute CREATE_CANONICAL_INDEX_SQL
      end
    end

    def dedupe_concordance_file
      @deduped_concordance_file = File.join(
        @db_dir,
        # Strip off possible double .txt.gz suffix on path to the compressed file.
        File.basename(@concordance_file).split(".")[0] + "_dedupe.txt"
      )
      if File.exist? @deduped_concordance_file
        Services.logger.info "deduped concordance #{@deduped_concordance_file} already exists, skipping"
      else
        cmd = if /\.gz$/.match?(@concordance_file)
          "zcat -cf #{@concordance_file} | sed '#{SED_DEDUPE_REGEX}' > #{@deduped_concordance_file}"
        else
          "sed '#{SED_DEDUPE_REGEX}' #{@concordance_file} > #{@deduped_concordance_file}"
        end
        Services.logger.info "deduping #{@concordance_file} to #{@deduped_concordance_file}..."
        system(cmd, exception: true)
      end
    end

    # WARNING: this is for testing only
    def to_h
      Hash.new { |h, k| h[k] = [] }.tap do |hash|
        @db.execute("SELECT variant,canonical FROM concordance").each do |row|
          hash[row[0]] << row[1]
        end
      end
    end

    def variant_to_canonical(variant)
      @db.execute("SELECT canonical FROM concordance WHERE variant=? AND canonical!=?", [variant, variant])
        .flatten
        .uniq
    end

    def canonical_to_variant(canonical)
      @db.execute("SELECT variant FROM concordance WHERE canonical=? AND variant!=?", [canonical, canonical])
        .flatten
        .uniq
    end

    def file_handler
      if /\.gz$/.match?(@concordance_file)
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
        v2c = variant_to_canonical(ocn)
        out_edges[ocn] = v2c if v2c.any?
        v2c.each do |to_ocn|
          ocns_to_check << to_ocn unless ocns_checked.include? to_ocn
        end
        c2v = canonical_to_variant(ocn)
        in_edges[ocn] = c2v if c2v.any?
        c2v.each do |from_ocn|
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
      variant_to_canonical(ocn).empty?
    end

    # Find the terminal ocn for a given ocn
    # Will fail endlessly if there are cycles.
    def canonical_ocn(ocn)
      canonical = variant_to_canonical(ocn)
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
          v2c = variant_to_canonical(o)
          if v2c.any?
            canonical.map! { |x| (x == o) ? v2c : x }.flatten!
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
