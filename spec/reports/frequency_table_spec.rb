require "spec_helper"
require "reports/frequency_table_chunk"

RSpec.describe Reports::FrequencyTableChunk do
  include_context "with tables for holdings"

  it "can generate a frequency table from a file of hathifile records" do
    Dir.mktmpdir do |tmpdir|
      outfile = File.join(tmpdir, "out.json")
      described_class.new(fixture("htitems_for_freqtable.txt"), outfile).run

      ft_from_report = FrequencyTable.new(data: File.read(outfile))
      ft_fixture = FrequencyTable.new(data: File.read(fixture("freqtable.json")))

      expect(ft_from_report).to eq(ft_fixture)
    end
  end
end
