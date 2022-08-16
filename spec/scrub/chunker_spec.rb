# frozen_string_literal: true

require "spec_helper"
require "scrub/chunker"

Settings.scrub_chunk_work_dir = "/tmp/scrub_chunks"
RSpec.describe Scrub::Chunker do
  let(:pre_chunked_file) { "spec/fixtures/pre_chunk.tsv" }
  let(:chunk_count) { 4 }
  it "splits input file into the desired number of chunks" do
    chunker = described_class.new(pre_chunked_file, chunk_count)
    # Start out with zero chunks.
    expect(chunker.chunks.size).to eq 0
    chunker.run
    # Get the expected number of files.
    expect(chunker.chunks.size).to eq chunk_count
    # Each file exists.
    0.upto(chunk_count-1).each do |i|
      expect(File.exist?(chunker.chunks[i])).to be true
    end
    chunker.cleanup!
    # Cleanup removed the chunks.
    0.upto(chunk_count-1).each do |i|
      expect(File.exist?(chunker.chunks[i])).to be false
    end
  end
end
