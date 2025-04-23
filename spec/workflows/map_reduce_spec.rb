require "workflows/map_reduce"
require "spec_helper"

class TestDataSource
  RECORD_COUNT = 20

  def initialize(base: {})
    @base = base
  end

  def dump_records(file)
    File.open(file, "w") do |f|
      1.upto(RECORD_COUNT).each do |i|
        f.puts @base.merge("id" => i).to_json
      end
    end
  end
end

# Trivial mapper that counts the number
# of lines in the input file
class TestMapper
  def initialize(infile, prefix: "")
    @infile = infile
    @prefix = prefix
  end

  def run
    File.open("#{@infile}.out", "w") do |f|
      f.puts(@prefix + File.readlines(@infile).count.to_s)
    end
  end
end

# Adds up whatever it reads from the json files
# (should work for array, string, integer; not object)
class TestReducer
  def initialize(working_directory:)
    @dir = working_directory
  end

  def run
    output = Dir.glob("#{@dir}/*.out")
      .map { |f| JSON.parse(File.read(f)) }
      .reduce(:+)

    File.open("#{ENV["TEST_TMP"]}/mapreduce_output", "w") do |f|
      f.puts(output)
    end
  end
end

RSpec.describe Workflows::MapReduce do
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

  let(:allrecords) { File.join(@tmpdir, "allrecords") }

  def workflow(records_per_job: 1, mapper_params: {}, data_source_params: {})
    described_class.new(
      working_directory: @tmpdir,
      records_per_job: records_per_job,
      components: {
        data_source: WorkflowComponent.new(TestDataSource, data_source_params),
        mapper: WorkflowComponent.new(TestMapper, mapper_params),
        reducer: WorkflowComponent.new(TestReducer)
      },
      test_mode: true
    )
  end

  it "passes through keyword parameters to data source" do
    workflow(data_source_params: {base: {label: "test"}}).run

    # each line should be a json object that has a key "label" and value "test"
    json_lines = File.open(allrecords).map { |l| JSON.parse(l) }
    expect(json_lines.map { |j| j["label"] }).to all eq("test")
  end

  it "passes through keyword parameters to mapper" do
    workflow(mapper_params: {prefix: "10"}).run

    # each intermediate file should contain "101" - the given prefix prepended
    # to the line count of the file
    intermediate_file_outputs =
      Dir.glob(File.join(@tmpdir, "*.out"))
        .map { |f| File.read(f).strip }

    expect(intermediate_file_outputs).to all eq("101")
  end

  it "dumps records to given directory" do
    workflow.run

    allrecords = File.join(@tmpdir, "allrecords")
    expect(File.size(allrecords)).to be > 0
    expect(File.readlines(allrecords).count).to be == TestDataSource::RECORD_COUNT
  end

  it "chunks records" do
    workflow(records_per_job: 8).run

    expect(File.readlines(File.join(@tmpdir, "records_00000.split")).count).to be == 8
    expect(File.readlines(File.join(@tmpdir, "records_00001.split")).count).to be == 8
    expect(File.readlines(File.join(@tmpdir, "records_00002.split")).count).to be == 4
    expect(File.exist?(File.join(@tmpdir, "records_00003.split"))).to be false
  end

  describe "frequency table jobs", type: :sidekiq_fake do
    it "queues one job for each chunk" do
      expect { workflow(records_per_job: 4).run }
        .to change(Jobs::Common.jobs, :size).by(5)

      expect(Jobs::Common.jobs.map { |j| j["args"][0] }).to all eq "TestMapper"
    end

    it "job reads from records_CHUNK and writes to records_CHUNK.freqtable.json" do
      workflow(records_per_job: 5).run
      expect(Jobs::Common.jobs[0]["args"]).to eq([
        "TestMapper",
        {},
        "#{@tmpdir}/records_00000.split"
      ])
    end
  end

  context "with inline callback testing" do
    # We can't test the callbacks directly without 'real' sidekiq, but we can
    # simulate.

    let(:output) { "#{ENV["TEST_TMP"]}/mapreduce_output" }

    let(:workflow) do
      described_class.new(
        working_directory: @tmpdir,
        records_per_job: 2,
        test_mode: true,
        # TODO provide component objects not hashes
        components: {
          data_source: WorkflowComponent.new(TestDataSource),
          mapper: WorkflowComponent.new(TestMapper),
          reducer: WorkflowComponent.new(TestReducer)
        }
      )
    end

    it "outputs a file with the reduced output" do
      expect { workflow.run }.to change { Dir.glob(output).count }.by(1)
    end

    it "outputs the expected reduced data" do
      workflow.run

      expect(File.read(output).strip).to eq(TestDataSource::RECORD_COUNT.to_s)
    end

    # See CostReportWorkflow::Callback -- deleting the intermediate files is currently
    # not enabled, but we may re-enable that in the future. Re-enable this test at that time.
    xit "cleans up when cost report completes" do
      workflow.run
      expect(File.exist?(@tmpdir)).to be false
    end
  end
end
