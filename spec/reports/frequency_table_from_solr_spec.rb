require "spec_helper"
require "reports/frequency_table_from_solr"

RSpec.describe Reports::FrequencyTableFromSolr do
  include_context "with tables for holdings"

  it "can generate a frequency table from a solr record" do
    Dir.mktmpdir do |tmpdir|
      # fixture: one michigan-deposited mpm with ocn 2779601
      record = fixture("solr_catalog_record.ndj")
      create(:holding,
        ocn: 2779601,
        organization: "upenn")

      outfile = File.join(tmpdir, "out.json")
      described_class.new(record, outfile).run

      # umich & upenn each have one mpm that two institutions hold
      ft_from_report = FrequencyTable.new(data: File.read(outfile))
      ft_fixture = FrequencyTable.new(data: File.read(fixture("freqtable_from_solr.json")))

      expect(ft_from_report).to eq(ft_fixture)
    end
  end

  it "can handle catalog record w/o ocn" do
    Dir.mktmpdir do |tmpdir|
      outfile = File.join(tmpdir, "out.json")
      described_class.new(fixture("solr_ocnless_record.ndj"), outfile).run

      ft_from_report = FrequencyTable.new(data: File.read(outfile))

      # one spm on the record, umich is depositor, should hold it
      expect(ft_from_report.fetch(organization: :umich, format: :spm, bucket: 1)).to eq(1)
    end
  end

  it "can handle serial record" do
    Dir.mktmpdir do |tmpdir|
      outfile = File.join(tmpdir, "out.json")
      described_class.new(fixture("solr_serial_record.ndj"), outfile).run

      ft_from_report = FrequencyTable.new(data: File.read(outfile))

      # no holdings loaded; bib format is serial, two items on record both
      # deposited by umich; they should hold them.
      expect(ft_from_report.fetch(organization: :umich, format: :ser, bucket: 1)).to eq(2)
    end
  end

  it "ignores pd items on record" do
    Dir.mktmpdir do |tmpdir|
      outfile = File.join(tmpdir, "out.json")
      described_class.new(fixture("solr_mixed_ic_pd_record.ndj"), outfile).run

      ft_from_report = FrequencyTable.new(data: File.read(outfile))

      # no holdings loaded; bib format is serial, 12 items on record, 3 pdus, 9 ic, all from umich
      # pd items should be ignored so serial count should be 9
      expect(ft_from_report.fetch(organization: :umich, format: :ser, bucket: 1)).to eq(9)
    end
  end
end
