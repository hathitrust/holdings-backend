# frozen_string_literal: true

require "spec_helper"
require "utils/tsv_reader"

RSpec.describe Utils::TSVReader do
  let(:reader) { described_class.new("spec/fixtures/test_sp_update_file.tsv") }

  it "#process_header" do
    header_str = "a\tb\tc"
    reader.process_header(header_str)
    expect(reader.header_index).to eq({0 => :a, 1 => :b, 2 => :c})
  end

  describe "#line_to_hash" do
    it "parses a line according to header" do
      # Gotta set the header or line_to_hash don't work
      reader.process_header("a\tb\tc")
      # now then
      expect(reader.line_to_hash("x\ty\tz")).to eq({a: "x", b: "y", c: "z"})
    end
    it "error if line column count is different from header column count" do
      # Set up a header with 3 cols and try to parse lines of different length.
      reader.process_header("a\tb\tc")
      # Too short
      rx1 = /Line \d+ has 2 cols, header has 3 cols/
      rx2 = /Line \d+ has 4 cols, header has 3 cols/
      expect { reader.line_to_hash("x\ty") }.to raise_error(IndexError, rx1)
      # Too long
      expect { reader.line_to_hash("x\ty\tz\tfoo") }.to raise_error(IndexError, rx2)
      # Just right!
      expect { reader.line_to_hash("x\ty\tz") }.not_to raise_error
    end
  end

  it "#run" do
    records = []
    reader.run do |record|
      records << record
    end
    expect(records.size).to eq 3
    expect(records).to eq [
      {local_id: "i1", ocn: "1", organization: "umich", local_bib_id: "updated"},
      {local_id: "i3", ocn: "3", organization: "umich", local_bib_id: "updated"},
      {local_id: "i9", ocn: "9", organization: "umich", local_bib_id: "updated"}
    ]
  end
end
