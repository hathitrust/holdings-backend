require "workflows/cost_report"
require "workflows/map_reduce"
require "reports/frequency_table_from_solr"
require "reports/cost_report"
require "spec_helper"

RSpec.describe Workflows::CostReport::DataSource do
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

RSpec.describe "cost report workflow integration" do
  include_context "with mocked solr response"

  let(:cost_report_glob) { "#{ENV["TEST_TMP"]}/cost_reports/*/costreport_*.tsv" }
  let(:freqtable_glob) { "#{ENV["TEST_TMP"]}/cost_report_freq/frequency_*.json" }

  let(:workflow) do
    Workflows::MapReduce.new(
      data_source: Workflows::CostReport::DataSource.to_s,
      mapper: Reports::FrequencyTableFromSolr.to_s,
      reducer: Reports::CostReport.to_s,
      reducer_params: {
        # these match the counts of IC items from solresponse.json -- i.e. what our mock solr
        # will return to work on -- plus a made-up 5 public domain volumes to help the math work out
        # below
        ht_item_count: 16,
        ht_item_pd_count: 5
      },
      chunk_size: 2,

      # We can't test the callbacks directly without 'real' sidekiq, but we can
      # simulate.
      test_mode: true
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
