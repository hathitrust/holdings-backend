# frozen_string_literal: true

require "set"

module DataSources
  # Set of Michigan/HathiTrust record IDs to consider as serials. Derived from
  # data from Michigan ILS
  class SerialsFile

    def initialize(filename)
      @filename = filename
      @bibkeys = Set.new
      load_serials
    end

    def matches_htitem?(htitem)
      bibkeys.include?(htitem.ht_bib_key.to_i)
    end

    private

    attr_reader :bibkeys

    def load_serials
      Services.logger.info("Loading serials file #{@filename}")
      File.open(@filename).each_line do |line|
        id, _ocns, _issns, _locations = line.chomp.split("\t")
        bibkeys.add(id.to_i)
      end
      Services.logger.info("Loaded serials file, #{bibkeys.count} records loaded")
    end

  end
end
