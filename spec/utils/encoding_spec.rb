# frozen_string_literal: true

require "utils/encoding"
require "spec_helper"

RSpec.describe Utils::Encoding do
  let(:valid_fixt) { fixture "valid_utf8.txt" }
  let(:non_valid_fixt) { fixture "non_valid_utf8.txt" }
  let(:valid_enc) { described_class.new(valid_fixt) }

  # Clean up
  after(:all) do
    Dir.glob("/tmp/Utils_Encoding_*").each do |f|
      FileUtils.rm(f)
    end
  end

  describe "#initialize" do
    it "requires a path to something existing" do
      expect { described_class.new(valid_fixt) }.to_not raise_error
      expect { described_class.new(nil) }.to raise_error IOError
      FileUtils.rm_f("#{ENV["TEST_TMP"]}/no_file")
      expect { described_class.new("#{ENV["TEST_TMP"]}/no_file") }.to raise_error IOError
    end
    it "sets @encoding on initialize" do
      expect(valid_enc.encoding).to eq "ASCII"
    end
    it "leaves @utf8_output and @diff unset until used" do
      expect(valid_enc.utf8_output).to eq nil
      expect(valid_enc.diff).to eq nil
    end
  end

  describe "#ascii_or_utf8?" do
    it "recognizes an all-utf8 file as such" do
      expect(valid_enc.ascii_or_utf8?).to be true
    end
    it "can tell when a file contains illegal utf8 sequences" do
      expect(described_class.new(non_valid_fixt).ascii_or_utf8?).to be false
    end
  end
  describe "#force_utf8" do
    it "takes a non-valid utf8 file and creates a copy without illegal input sequences" do
      enc = described_class.new(non_valid_fixt)
      # Make sure that we think it is non-valid
      expect(enc.ascii_or_utf8?).to be false
      # See if we can force it to be valid
      expect(enc.force_utf8).to be true
      # Let's double check...
      # Pass the converted output file as input to a new encoder,
      # and ask the new encoder if that input is valid
      expect(described_class.new(enc.utf8_output).ascii_or_utf8?).to be true
    end
    it "creates a diff file with only the post-encoding version" do
      enc = described_class.new(non_valid_fixt)
      expect(enc.diff.nil?).to be true
      enc.force_utf8
      expect(enc.diff.nil?).to be false
      # In this case there should only be one line that differs
      expect(File.new(enc.diff).count).to be 1
    end
  end
  describe "#capture_outs" do
    it "captures the different outputs separately" do
      outs = described_class.new(File::NULL).capture_outs("echo 'foo'")
      expect(outs[:stat]).to eq 0
      expect(outs[:stderr]).to eq ""
      expect(outs[:stdout]).to eq "foo"
    end
    it "captures stderr if there is any" do
      outs = described_class.new(File::NULL).capture_outs("echo 'foo' 1>&2")
      expect(outs[:stat]).to eq 0
      expect(outs[:stderr]).to eq "foo"
      expect(outs[:stdout]).to eq ""
    end
    it "captures exit status" do
      # But it multiplies exit status by 256?
      outs = described_class.new(File::NULL).capture_outs("exit 1")
      expect(outs[:stat]).to eq 256
      expect(outs[:stderr]).to eq ""
      expect(outs[:stdout]).to eq ""
    end
  end
end
