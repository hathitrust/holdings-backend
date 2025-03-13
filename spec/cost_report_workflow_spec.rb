require "cost_report_workflow"
require "frequency_table"
require "spec_helper"

RSpec.describe CostReportWorkflow do
  include_context "with mocked solr response"

  around(:each) do |example|
    @tmpdir = Dir.mktmpdir("test-cost-report-workflow")
    begin
      example.run
    ensure
      # Not using the block form of mktmpdir because we may
      # eventually remove this inline.
      FileUtils.remove_entry @tmpdir if File.exist? @tmpdir
    end
  end

  def workflow_with_chunk_size(size)
    # item count shouldn't matter - not being tested here as it's only used in
    # the callback for the final cost report - but we must provide it
    described_class.new(working_directory: @tmpdir, ht_item_count: 0, ht_item_pd_count: 0, chunk_size: size)
  end

  it "dumps solr records to given directory" do
    workflow_with_chunk_size(5).run

    allrecords = File.join(@tmpdir, "allrecords.ndj")
    expect(File.size(allrecords)).to be > 0
    expect(File.readlines(allrecords).count).to be == 5
  end

  it "chunks solr records" do
    workflow_with_chunk_size(2).run

    expect(File.readlines(File.join(@tmpdir, "records_00000.ndj")).count).to be == 2
    expect(File.readlines(File.join(@tmpdir, "records_00001.ndj")).count).to be == 2
    expect(File.readlines(File.join(@tmpdir, "records_00002.ndj")).count).to be == 1
    expect(File.exist?(File.join(@tmpdir, "records_00003.ndj"))).to be false
  end

  describe "frequency table jobs", type: :sidekiq_fake do
    it "queues one job for each chunk" do
      expect { workflow_with_chunk_size(1).run }
        .to change(Jobs::Common.jobs, :size).by(5)

      expect(Jobs::Common.jobs.map { |j| j["args"][0] }).to all eq "Reports::FrequencyTableFromSolr"
    end

    it "job reads from records_CHUNK and writes to records_CHUNK.freqtable.json" do
      workflow_with_chunk_size(5).run
      expect(Jobs::Common.jobs[0]["args"]).to eq([
        "Reports::FrequencyTableFromSolr",
        {},
        "#{@tmpdir}/records_00000.ndj",
        "#{@tmpdir}/records_00000.freqtable.json"
      ])
    end
  end

  context "with inline callback testing" do
    # We can't test the callbacks directly without 'real' sidekiq, but we can
    # simulate.

    let(:cost_report_glob) { "#{ENV["TEST_TMP"]}/cost_reports/*/costreport_*.tsv" }
    let(:freqtable_glob) { "#{ENV["TEST_TMP"]}/cost_report_freq/frequency_*.json" }

    let(:workflow) do
      described_class.new(
        working_directory: @tmpdir,
        chunk_size: 2,
        inline_callback_test: true,
        # these match the counts of IC items from solresponse.json -- i.e. what our mock solr
        # will return to work on -- plus a made-up 5 public domain volumes to help the math work out
        # below
        ht_item_count: 16,
        ht_item_pd_count: 5
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

    # See CostReportWorkflow::Callback -- deleting the intermediate files is currently
    # not enabled, but we may re-enable that in the future. Re-enable this test at that time.
    xit "cleans up when cost report completes" do
      workflow.run
      expect(File.exist?(@tmpdir)).to be false
    end
  end
end
