# frozen_string_literal: true

require "spec_helper"
require "scrub/chunker"

Settings.scrub_chunk_work_dir = "/tmp/scrub_chunks"
RSpec.describe Scrub::Chunker do
  let(:pre_chunked_file) { "spec/fixtures/pre_chunk.tsv" }
  let(:input_line_count) { 16 }
  let(:chunk_count) { 4 }
  let(:expected_chunk_line_count) { 4 }
  it "splits input file into the desired number of chunks" do
    chunker = described_class.new(pre_chunked_file, chunk_count: chunk_count, out_ext: "tsv")

    # Start out with zero chunks.
    expect(chunker.chunks.size).to eq 0
    chunker.run

    # Get the expected number of files.
    expect(chunker.chunks.size).to eq chunk_count

    # Each file:
    0.upto(chunk_count - 1).each do |i|
      # exists:
      expect(File.exist?(chunker.chunks[i])).to be true

      # has the expected name:
      expect(chunker.chunks[i]).to end_with "split_0#{i}.tsv"

      # has the expected number of lines:
      chunk_line_count = `wc -l #{chunker.chunks[i]}`.split.first.to_i
      # (for some reason splitting a 16 line file into 4 with split
      # does not guarantee 4 files with exactly 4 lines
      # sometimes there are 3-5 lines, but it should all add up.)
      expect(chunk_line_count).to be_within(1).of(expected_chunk_line_count)

      # is internally sorted:
      expect(system("sort -c #{chunker.chunks[i]}")).to be true
    end

    # Check that the line count of all the chunks add up to the line count of pre_chunked_file
    all_chunks_line_count = `wc -l #{chunker.chunks.join(" ")} | tail -1`.split.first.to_i
    expect(all_chunks_line_count).to eq input_line_count

    # Check that the chunked ouptput equals the input:
    # (header line is discarded from input,
    # and a uuid column is added to output,
    # so we have to remove those, hence the cut-f1,2 & grep -v)
    all_chunks_md5 = `cut -f1,2 #{chunker.chunks.join(" ")} | sort -n | md5sum`
    pre_chunk_md5 = `grep -v OCN #{pre_chunked_file} | sort -n | md5sum`
    expect(all_chunks_md5).to eq pre_chunk_md5

    chunker.cleanup!
    # Cleanup removed the chunks.
    0.upto(chunk_count - 1).each do |i|
      expect(File.exist?(chunker.chunks[i])).to be false
    end
  end
end
