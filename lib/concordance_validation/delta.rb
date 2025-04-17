# frozen_string_literal: true

require "date"
require "zlib"
require "settings"

module ConcordanceValidation
  # Performs a diff of two validated concordances
  class Delta
    DIFF_FILE_BASE_TEMPLATE = "comm_diff_YYYYMMDD.txt"
    def self.diffs_directory
      File.join(Settings.concordance_path, "diffs")
    end

    def self.diff_file_base(date: Date.today)
      DIFF_FILE_BASE_TEMPLATE.gsub("YYYYMMDD", date.strftime("%Y-%m-%d"))
    end

    def self.adds_file(date: Date.today)
      File.join(diffs_directory, diff_file_base(date: date) + ".adds")
    end

    def self.deletes_file(date: Date.today)
      File.join(diffs_directory, diff_file_base(date: date) + ".deletes")
    end

    def initialize(old_concordance, new_concordance)
      @old_concordance = old_concordance
      @new_concordance = new_concordance
    end

    def run
      # Lines only in old concordance == deletes
      comm_cmd = "bash -c 'comm -23 <(#{sort_cmd @old_concordance}) <(#{sort_cmd @new_concordance}) > #{deletes_file}'"
      system(comm_cmd, exception: true)
      # Lines only in new concordance == adds
      comm_cmd = "bash -c 'comm -13 <(#{sort_cmd @old_concordance}) <(#{sort_cmd @new_concordance}) > #{adds_file}'"
      system(comm_cmd, exception: true)
    end

    # Apply sort, or gunzip and sort, depending on file extension.
    # This is to be embedded in one of the top-level `comm` commands.
    def sort_cmd(path)
      if path.end_with?(".gz")
        "zcat #{path} | sort"
      else
        "sort #{path}"
      end
    end

    def adds_file
      @adds_file ||= self.class.adds_file
    end

    def deletes_file
      @deletes_file ||= self.class.deletes_file
    end
  end
end
