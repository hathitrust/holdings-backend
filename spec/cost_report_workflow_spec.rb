require "cost_report_workflow"
require "frequency_table"
require "spec_helper"

RSpec.describe CostReportWorkflow do
  before(:each) do
    stub_request(:get, "http://localhost:8983/solr/catalog/select?cursorMark=*&fl=ht_json,id,oclc,oclc_search,title,format&fq=ht_rightscode:(ic%20op%20und%20nobody%20pd-pvt)&q=*:*&rows=5000&sort=id%20asc&wt=json")
      .with(
        headers: {
          "Accept" => "*/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "User-Agent" => "Faraday v2.12.2"
        }
      )
      .to_return(status: 200,
        body: File.read(fixture("solr_response.json")),
        headers: {
          "Content-type" => "application/json"
        })
  end

  around(:each) do |example|
    @tmpdir = Dir.mktmpdir("test-cost-report-workflow")
    begin
      ClimateControl.modify(
        SOLR_URL: "http://localhost:8983/solr/catalog"
      ) do
        example.run
      end
    # The callback will delete our temporary directory out from under us; don't
    # freak out
    ensure Errno::ENOENT => e
           FileUtils.remove_entry @tmpdir if File.exist? @tmpdir
    end
  end

  it "dumps solr records to given directory" do
    allrecords = File.join(@tmpdir, "allrecords.ndj")
    described_class.new(working_directory: @tmpdir).run

    expect(File.size(allrecords)).to be > 0
    expect(File.readlines(allrecords).count).to be == 5
  end

  it "chunks solr records" do
    described_class.new(working_directory: @tmpdir, chunk_size: 2).run

    expect(File.readlines(File.join(@tmpdir, "records_00000.ndj")).count).to be == 2
    expect(File.readlines(File.join(@tmpdir, "records_00001.ndj")).count).to be == 2
    expect(File.readlines(File.join(@tmpdir, "records_00002.ndj")).count).to be == 1
    expect(File.exist?(File.join(@tmpdir, "records_00003.ndj"))).to be false
  end

  describe "frequency table jobs", type: :sidekiq_fake do
    it "queues one job for each chunk" do
      expect { described_class.new(working_directory: @tmpdir, chunk_size: 1).run }
        .to change(Jobs::Common.jobs, :size).by(5)

      expect(Jobs::Common.jobs.map { |j| j["args"][0] }).to all eq "Reports::FrequencyTableFromSolr"
    end

    it "job reads from records_CHUNK and writes to records_CHUNK.freqtable.json" do
      described_class.new(working_directory: @tmpdir, chunk_size: 5).run
      expect(Jobs::Common.jobs[0]["args"]).to eq([
        "Reports::FrequencyTableFromSolr",
        {},
        "#{@tmpdir}/records_00000.ndj",
        "#{@tmpdir}/records_00000.freqtable.json"
      ])
    end
  end

  context "with inline callback testing" do
    include_context "with tables for holdings"
    # We can't test the callbacks directly without 'real' sidekiq, but we can
    # simulate.

    let(:cost_report_glob) { "#{ENV["TEST_TMP"]}/cost_reports/*/costreport_*.tsv" }
    let(:freqtable_glob) { "#{ENV["TEST_TMP"]}/cost_report_freq/frequency_*.json" }

    let(:workflow) do
      described_class.new(
        working_directory: @tmpdir,
        chunk_size: 2,
        inline_callback_test: true
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
      # The data here is only used for the counts of items, not the actual data!
      # The items in the solr file are all Michigan, and we have no holdings,
      # so everybody's costs should be zero but Michigan.
      11.times { load_test_data(build(:ht_item, rights: "ic", collection_code: "PU")) }
      5.times { load_test_data(build(:ht_item, rights: "pd", collection_code: "PU")) }

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

    # See CostReportWorkflow::Callback -- deleting the intermediate files is currently
    # not enabled, but we may re-enable that in the future. Re-enable this test at that time.
    xit "cleans up when cost report completes" do
      workflow.run
      expect(File.exist?(@tmpdir)).to be false
    end
  end
end
