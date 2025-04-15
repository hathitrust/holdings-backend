# frozen_string_literal: true

require "services"

module Loader
  # Loads file of records that have been sorted by OCN
  class ConcordanceLoader
    def initialize(date, load_batch_size: 10_000)
      @date = date
      @load_batch_size = load_batch_size
    end

    # FIXME: this duplicates some code in the concordance validation PR
    # Can probably extract it to a Delta class
    def adds_file
      File.join(Settings.concordance_path, "diffs", "comm_diff_#{Date.parse(@date).strftime("%Y-%m-%d")}.txt.adds")
    end

    def deletes_file
      File.join(Settings.concordance_path, "diffs", "comm_diff_#{Date.parse(@date).strftime("%Y-%m-%d")}.txt.deletes")
    end

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
end
