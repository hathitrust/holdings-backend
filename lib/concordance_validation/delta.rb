# frozen_string_literal: true

require "zlib"
require "settings"

module ConcordanceValidation

  # Performs a diff of two validated concordances
  class Delta
    attr_accessor :old_conc, :new_conc, :adds, :deletes

    def initialize(old_conc_filename, new_conc_filename)
      @old_conc = open_concordance(old_conc_filename)
      @new_conc = open_concordance(new_conc_filename)
      @adds = Hash.new {|h, resolved| h[resolved] = Set.new }
      @deletes = Hash.new {|h, resolved| h[resolved] = Set.new }
    end

    def run
      old_conc_lines = old_conc.readlines.to_set
      new_conc.each do |line|
        if old_conc_lines.include? line
          old_conc_lines.delete(line)
        else
          dead_ocn, resolved_ocn = line.chomp.split("\t")
          adds[resolved_ocn] << dead_ocn
        end
      end
      write(File.open(diff_out_path + ".adds", "w"), adds)
      deletes_from_remaining_lines(old_conc_lines)
      write(File.open(diff_out_path + ".deletes", "w"), deletes)
    end

    def write(fout, diffs)
      diffs.keys.sort.each do |resolved_ocn|
        diffs[resolved_ocn].each do |dead_ocn|
          fout.puts [dead_ocn, resolved_ocn].join("\t")
        end
      end
      fout.flush
    end

    def open_concordance(filename)
      if /\.gz$/.match?(filename)
        Zlib::GzipReader.open(Settings.concordance_path + "/validated/" + filename)
      else
        File.open(Settings.concordance_path + "/validated/" + filename)
      end
    end

    def diff_out_path
      Settings.concordance_path + "/diffs/comm_diff_#{DateTime.now.strftime("%Y-%m-%d")}.txt"
    end

    private

    def deletes_from_remaining_lines(lines)
      lines.each do |line|
        dead_ocn, resolved_ocn = line.chomp.split("\t")
        deletes[resolved_ocn] << dead_ocn
      end
    end

  end
end
