# frozen_string_literal: true

require "zlib"
require "settings"
require "tmpdir"

module ConcordanceValidation
  # Performs a diff of two validated concordances
  class Delta
    def self.validated_concordance_path(concordance)
      File.join(Settings.concordance_path, "validated", concordance)
    end

    def initialize(old_conc_filename, new_conc_filename)
      @old_conc = self.class.validated_concordance_path old_conc_filename
      @new_conc = self.class.validated_concordance_path new_conc_filename
    end

    def run
      Dir.mktmpdir do
        # Lines only in old concordance == deletes
        comm_cmd = "bash -c 'comm -23 <(#{sort_cmd @old_conc}) <(#{sort_cmd @new_conc}) > #{deletes_file}'"
        system(comm_cmd)
        # Lines only in new concordance == adds
        comm_cmd = "bash -c 'comm -13 <(#{sort_cmd @old_conc}) <(#{sort_cmd @new_conc}) > #{adds_file}'"
        system(comm_cmd)
      end
    end

    # Apply sort, or gunzip and sort, depending on file extension.
    # This is to be embedded in one of the top-level `comm` commands.
    def sort_cmd(path)
      if /\.gz$/.match?(path)
        "zcat #{path} | sort"
      else
        "sort #{path}"
      end
    end

    def adds_file
      @adds_file ||= diff_out_path + ".adds"
    end

    def deletes_file
      @deletes_file ||= diff_out_path + ".deletes"
    end

    def diff_out_path
      File.join(Settings.concordance_path, "diffs", "comm_diff_#{DateTime.now.strftime("%Y-%m-%d")}.txt")
    end
  end
end
