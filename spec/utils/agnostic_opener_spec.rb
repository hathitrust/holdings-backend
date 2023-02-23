# frozen_string_literal: true

require "utils/agnostic_opener"
require "spec_helper"

RSpec.describe Utils::AgnosticOpener do
  # files: a list of files with different combinations of encoding,
  # newlines and gzippedness, all with the same contents: #{expected_out}
  let(:files) { Dir.glob(fixture("open_whatever/*")) }
  let(:expected_out) { ["à\n", "b\n", "ç\n", "d\n"] }
  let(:gzipped) { fixture("open_whatever/gzipped.txt.gz") }
  let(:original) { fixture("open_whatever/original.txt") }

  def t(p)
    described_class.new(p)
  end

  describe "initialize" do
    it "requires a path that points to a file" do
      expect { t(nil) }.to raise_error ArgumentError, /path is nil/
      expect { t("/foo/bar.txt") }.to raise_error ArgumentError, /path not file/
      expect { t(original) }.not_to raise_error
    end

    it "has a reader for path" do
      opener = t(original)
      expect(opener.path).to eq original
    end
  end

  describe "gz?" do
    it "is true if file ends in '.gz'" do
      expect(t(original).gz?).to be false
      expect(t(gzipped).gz?).to be true
    end
  end

  describe "ensure_uncompressed" do
    it "makes sure compressed files are uncompressed" do
      opener = t(gzipped)
      expect(opener.gz?).to be true
      expect(opener.tmp_path).to be nil
      # Once we uncompress, we set tmp_path
      opener.ensure_uncompressed
      expect(opener.gz?).to be false
      expect(opener.tmp_path).not_to be nil
      # Make a copy of tmp_path so we can check cleanup
      tmp_path_copy = opener.tmp_path
      expect(File.exist?(tmp_path_copy)).to be true
      opener.cleanup!
      # tmp path gone
      expect(File.exist?(tmp_path_copy)).to be false
    end
  end

  describe "open" do
    it "can open files regardless of gzippedness" do
      files.each do |test_file|
        opener = t(test_file)
        opener.open do |file|
          expect(file).to be_a File
          # We can get a line count
          expect(file.count).to eq expected_out.size
          # Once we open a file it will have been decompressed
          # and its path stripped of .gz
          expect(opener.gz?).to be false
        end
      end
    end
  end

  # Tests the whole thing:
  describe "readlines" do
    it "reads lines from file regardless of newlines" do
      files.each do |test_file|
        expect(t(test_file).readlines.to_a).to eq expected_out
      end
    end
  end
end
