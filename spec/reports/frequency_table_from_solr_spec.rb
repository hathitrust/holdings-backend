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

  context "with temp directory" do
    around(:each) do |example|
      Dir.mktmpdir do |tmpdir|
        @tmpdir = tmpdir
        example.run
        @tmpdir = nil
      end
    end

    let(:outfile) { File.join(@tmpdir, "out.json") }
    let(:ft_from_report) { FrequencyTable.new(data: File.read(outfile)) }

    def ft_report_freq(organization, format)
      ft_from_report.frequencies(organization: organization, format: format).first
    end

    it "can handle catalog record w/o ocn" do
      described_class.new(fixture("solr_ocnless_record.ndj"), outfile).run

      # one spm on the record, umich is depositor, should hold it
      expect(ft_report_freq(:umich, :spm)).to eq(Frequency.new(bucket: 1, frequency: 1))
    end

    it "can handle serial record" do
      described_class.new(fixture("solr_serial_record.ndj"), outfile).run

      # no holdings loaded; bib format is serial, two items on record both
      # deposited by umich; they should hold them.
      expect(ft_report_freq(:umich, :ser)).to eq(Frequency.new(bucket: 1, frequency: 2))
    end

    it "ignores pd items on record" do
      described_class.new(fixture("solr_mixed_ic_pd_record.ndj"), outfile).run

      # no holdings loaded; bib format is serial, 12 items on record, 3 pdus, 9 ic, all from umich
      # pd items should be ignored so serial frequency should be 9
      expect(ft_report_freq(:umich, :ser)).to eq(Frequency.new(bucket: 1, frequency: 9))
    end
  end
end
