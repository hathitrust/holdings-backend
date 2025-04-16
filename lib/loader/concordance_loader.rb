# frozen_string_literal: true

require "services"

module Loader
  # Loads TSV file(s) of records in "VARIANT\tCANONICAL" format.
  #
  # Can load from date in YYYYMMDD format in which case we load from delta files
  # or from a validated full concordance file in which case we truncate and load from
  # that file.
  #
  # We don't really care about the file extension of the full file since this class
  # will accept anything that is not YYYYMMDD.
  #
  # If this proves onerous we can introduce a Thor subcommand.
  class ConcordanceLoader
    def self.for(filename_or_date)
      if filename_or_date.match?(/^\d{8}$/)
        ConcordanceLoaderDelta.new(filename_or_date)
      else
        ConcordanceLoaderFull.new(filename_or_date)
      end
    end

    def initialize(filename_or_date, load_batch_size: 10_000)
      @filename_or_date = filename_or_date
      @load_batch_size = load_batch_size
    end

    # FIXME: this duplicates some code in the concordance validation PR
    # Can probably extract it to a Delta class
    def adds_file
      File.join(Settings.concordance_path, "diffs", "comm_diff_#{Date.parse(@filename_or_date).strftime("%Y-%m-%d")}.txt.adds")
    end

    def deletes_file
      File.join(Settings.concordance_path, "diffs", "comm_diff_#{Date.parse(@filename_or_date).strftime("%Y-%m-%d")}.txt.deletes")
    end

    # ConcordanceLoaderFull subclass will truncate the database, default behavior is no-op.
    def prepare
    end

    # Default behavior is to load adds and deletes from deltas.
    # ConcordanceLoaderFull has no deletes file, so it will return false.
    def deletes?
      true
    end

    # on_duplicate_key_update suppresses exception when testing the same set of deltas
    # in development. It is unlikely to have any effect in production but should not
    # have any negative side effects since the primary key is the whole row so there is
    # no net effect if loading a dupe.
    def load(batch)
      Services[:concordance_table].on_duplicate_key_update.import([:variant, :canonical], batch.compact)
    end

    def batches_for(enumerable)
      enumerable.each_slice(@load_batch_size)
    end

    def delete(batch)
      Services[:concordance_table].where([:variant, :canonical] => batch.compact).delete
    end

    # return [variant, canonical]
    def item_from_line(line)
      line.chomp!
      return nil if line.empty?
      line.split("\t").map(&:to_i)
    end
  end

  # Updates existing concordance data in the oclc_concordance table using an .adds and .deletes file.
  # The superclass provides all the default behavior. Defining an subclass to make the semantics
  # a little bit clearer.
  class ConcordanceLoaderDelta < ConcordanceLoader
  end

  class ConcordanceLoaderFull < ConcordanceLoader
    # Truncate the database when loading full concordance
    def prepare
      Services[:concordance_table].truncate
    end

    # This class processes only adds, no deletes (because everything is deleted by `prepare`).
    def deletes?
      false
    end

    # The phctl argument is the path to the concordance file
    def adds_file
      @filename_or_date
    end
  end
end
