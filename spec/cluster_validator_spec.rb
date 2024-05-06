# frozen_string_literal: true

require "spec_helper"
require "loader/cluster_loader"
require_relative "../bin/cluster_validator"

RSpec.describe ClusterValidator do
  let(:cluster_validator) { described_class.new }
  # The output file will have 2 lines, header and footer, even if no body.
  # So if the output file has 2 lines it is "empty" for the purposes of these tests.
  let(:empty_file_line_count) { 2 }
  let(:one_invalid_cluster_line_count) { 3 }
  # Files only differ in commitment.phase (1 in valid, 999 in invalid)
  let(:valid_cluster_fixt) { fixture("single_cluster_valid.json") }
  let(:invalid_cluster_fixt) { fixture("single_cluster_invalid.json") }
  before(:each) do
    Cluster.collection.find.delete_many
  end
  def get_output_lines
    described_class.new.run
    File.read(cluster_validator.output_path).split("\n")
  end
  it "makes an outfile when it runs" do
    expect(File.exist?(cluster_validator.output_path)).to be false
    cluster_validator.run
    expect(File.exist?(cluster_validator.output_path)).to be true
  end
  it "makes an empty-ish outfile if there are no clusters" do
    # empty-ish meaning it'll only have the header and footer, which begin with "#".
    lines = get_output_lines
    expect(lines.count).to eq empty_file_line_count
    expect(lines[0]).to start_with("#")
    expect(lines[1]).to start_with("#")
  end
  it "does NOT count valid clusters" do
    # Start with loading a valid cluster, and verify.
    Loader::ClusterLoader.new.load(valid_cluster_fixt)
    # Verify we have one valid cluster.
    # Verify it does not count towards the report.
    expect(Cluster.count).to eq 1
    expect(Cluster.first.valid?).to be true
    expect(get_output_lines.count).to eq empty_file_line_count
  end
  it "DOES count invalid clusters" do
    # Start with loading an invalid cluster, and verify.
    l = Loader::ClusterLoader.new
    l.load(invalid_cluster_fixt)
    # Verify we have one invalid cluster.
    # Verify it does count towards the report.
    expect(Cluster.count).to eq 1
    # need to load the entire cluster to validate subdocuments from
    # previously-persisted documents
    # https://jira.mongodb.org/browse/MONGOID-5704
    c = Cluster.first
    doc = c.as_document
    expect(c.valid?).to be false
    expect(get_output_lines.count).to eq one_invalid_cluster_line_count
  end
end
