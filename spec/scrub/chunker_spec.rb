# frozen_string_literal: true

require "spec_helper"
require "scrub/chunker"

Settings.scrub_chunk_work_dir = "/tmp/scrub_chunks"
RSpec.describe Scrub::Chunker do
  let(:pre_chunked_file) { "spec/fixtures/pre_chunk.tsv" }
  let(:chunk_count) { 4 }
  it "chunks" do
    chunker = described_class.new(pre_chunked_file, chunk_count)
    expect(chunker.chunks.size).to eq 0
    chunker.run
    expect(chunker.chunks.size).to eq chunk_count
    chunker.cleanup!
  end
end
