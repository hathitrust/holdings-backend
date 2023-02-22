# frozen_string_literal: true

require "utils/encoding"
require "spec_helper"

RSpec.describe Utils::Encoding do
  let(:valid_fixt) { fixture "valid_utf8.txt" }
  let(:non_valid_fixt) { fixture "non_valid_utf8.txt" }

  describe "#initialize" do
    it "requires a path to something existing" do
      expect { described_class.new(valid_fixt) }.to_not raise_error
      expect { described_class.new(nil) }.to raise_error IOError
      FileUtils.rm_f("#{ENV["TEST_TMP"]}/no_file")
      expect { described_class.new("#{ENV["TEST_TMP"]}/no_file") }.to raise_error IOError
    end
  end

  describe "#ascii_or_utf8?" do
    it "recognizes an all-utf8 file as such" do
      expect(described_class.new(valid_fixt).ascii_or_utf8?).to be true
    end
    it "can tell when a file contains illegal utf8 sequences" do
      expect(described_class.new(non_valid_fixt).ascii_or_utf8?).to be false
    end
  end
  describe "#force_utf8" do
    it "takes a non-valid utf8 file and creates a copy without illegal input sequences" do
      fixed = described_class.new(non_valid_fixt).force_utf8
      expect(described_class.new(fixed).ascii_or_utf8?).to be true
      # There's only one line with illegal sequences, a diff should confirm.
      # But we have to count the diffs, because doing anything with the diff
      # would mean doing something with the illegal sequence, and we cannot
      # have that now can we.
      diffs = `diff -y --suppress-common-lines #{non_valid_fixt} #{fixed} | egrep -c .`
      expect(diffs.strip).to eq "1"
    end
  end
  describe "#capture_outs" do
    it "captures the different outputs separately" do
      outs = described_class.new("/dev/null").capture_outs("echo 'foo'")
      expect(outs[:stat]).to eq 0
      expect(outs[:stderr]).to eq ""
      expect(outs[:stdout]).to eq "foo"
    end
    it "captures stderr if there is any" do
      outs = described_class.new("/dev/null").capture_outs("echo 'foo' 1>&2")
      expect(outs[:stat]).to eq 0
      expect(outs[:stderr]).to eq "foo"
      expect(outs[:stdout]).to eq ""
    end
    it "captures exit status" do
      # But it multiplies exit status by 256?
      outs = described_class.new("/dev/null").capture_outs("exit 1")
      expect(outs[:stat]).to eq 256
      expect(outs[:stderr]).to eq ""
      expect(outs[:stdout]).to eq ""
    end
  end
end
