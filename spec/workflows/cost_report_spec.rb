require "workflows/cost_report"
require "workflows/map_reduce"
require "frequency_table"
require "reports/cost_report"
require "spec_helper"

RSpec.describe Workflows::CostReport do
  describe Workflows::CostReport::DataSource do
    include_context "with mocked solr response"

    around(:each) do |example|
      Dir.mktmpdir("test-cost-report-workflow") do |tmpdir|
        @tmpdir = tmpdir
        example.run
      end
    end

    it "dumps solr records to given directory" do
      allrecords = File.join(@tmpdir, "allrecords.ndj")
      described_class.new.dump_records(allrecords)

      expect(File.size(allrecords)).to be > 0
      expect(File.readlines(allrecords).count).to be == 5
    end
  end

  describe Workflows::CostReport::Analyzer do
    include_context "with tables for holdings"

    it "can generate a frequency table from a solr record" do
      Dir.mktmpdir do |tmpdir|
        # fixture: one michigan-deposited mpm with ocn 2779601
        record = fixture("solr_catalog_record.ndj")
        create(:holding,
          ocn: 2779601,
          organization: "upenn")

        outfile = File.join(tmpdir, "out.json")
        described_class.new(record, output: outfile).run

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
        described_class.new(fixture("solr_ocnless_record.ndj"), output: outfile).run

        # one spm on the record, umich is depositor, should hold it
        expect(ft_report_freq(:umich, :spm)).to eq(Frequency.new(bucket: 1, frequency: 1))
      end

      it "can handle serial record" do
        described_class.new(fixture("solr_serial_record.ndj"), output: outfile).run

        # no holdings loaded; bib format is serial, two items on record both
        # deposited by umich; they should hold them.
        expect(ft_report_freq(:umich, :ser)).to eq(Frequency.new(bucket: 1, frequency: 2))
      end

      it "ignores pd items on record" do
        described_class.new(fixture("solr_mixed_ic_pd_record.ndj"), output: outfile).run

        # no holdings loaded; bib format is serial, 12 items on record, 3 pdus, 9 ic, all from umich
        # pd items should be ignored so serial frequency should be 9
        expect(ft_report_freq(:umich, :ser)).to eq(Frequency.new(bucket: 1, frequency: 9))
      end
    end
  end

  describe "integration" do
    include_context "with mocked solr response"

    let(:cost_report_glob) { "#{ENV["TEST_TMP"]}/cost_reports/*/costreport_*.tsv" }
    let(:freqtable_glob) { "#{ENV["TEST_TMP"]}/cost_report_freq/frequency_*.json" }

    let(:workflow) do
      Workflows::MapReduce.new(
        records_per_job: 2,
        test_mode: true,
        components: {
          data_source: WorkflowComponent.new(Workflows::CostReport::DataSource),
          mapper: WorkflowComponent.new(Workflows::CostReport::Analyzer),
          reducer: WorkflowComponent.new(
            Reports::CostReport,
            {
              # these match the counts of IC items from solresponse.json -- i.e. what our mock solr
              # will return to work on -- plus a made-up 5 public domain volumes to help the math work out
              # below
              ht_item_count: 16,
              ht_item_pd_count: 5
            }
          )
        }
      )
    end

    it "outputs a cost report" do
      expect { workflow.run }.to change { Dir.glob(cost_report_glob).count }.by(1)
    end

    it "outputs a frequency table" do
      expect { workflow.run }.to change { Dir.glob(freqtable_glob).count }.by(1)
    end

    it "outputs some data in the cost report" do
      old_target_cost = Settings.target_cost
      Settings.target_cost = 16

      workflow.run

      costreport = File.read(Dir.glob(cost_report_glob).first)

      expect(costreport).to match(/^Total weight: 8.0/m)
      expect(costreport).to match(/^Num volumes: 16$/m)
      expect(costreport).to match(/^Num pd volumes: 5$/m)
      expect(costreport).to match(/^umich\t3.0\t8.0\t0.0.*/m)
      expect(costreport).to match(/^upenn\t0.0\t0.0\t0.0.*/m)
    ensure
      Settings.target_cost = old_target_cost
    end

    it "outputs the expected frequency table" do
      workflow.run

      freqtable = Dir.glob(freqtable_glob).first
      ft = FrequencyTable.new(data: File.read(freqtable))

      # {"umich"=>{"mpm"=>{"1"=>8}, "spm"=>{"1"=>3}}}
      expect(ft.frequencies(organization: :umich, format: :mpm))
        .to contain_exactly(Frequency.new(bucket: 1, frequency: 8))

      expect(ft.frequencies(organization: :umich, format: :spm))
        .to contain_exactly(Frequency.new(bucket: 1, frequency: 3))
    end
  end
end
