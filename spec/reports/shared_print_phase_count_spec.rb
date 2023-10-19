require "reports/shared_print_phase_count"
require "spec_helper"

RSpec.describe Reports::SharedPrintPhaseCount do
  let(:org) { "umich" }
  let(:phase) { 3 }
  let(:report) { described_class.new(phase: phase) }
  let(:commitment_count) { 5 }
  before(:each) do
    Cluster.collection.find.delete_many
  end
  it "gets commitments per phase, puts them in a file" do
    # Make 5 umich commitments with phase:3 (these we want)
    # and 5 umich with phase 0 (decoys)
    commitments = []
    1.upto(commitment_count) do |_i|
      commitments << build(:commitment, organization: org, phase: phase)
      commitments << build(:commitment, organization: org, phase: 0)
    end
    cluster_tap_save(*commitments)
    # Verify that the report script sees the 5 with phase 3 and no decoys.
    expect(report.commitments.count).to eq 5
    # Actually run the report and check the output file
    report.run
    lines = File.read(report.output.file).split("\n")
    expect(lines.count).to eq 2
    expect(lines.first).to eq ["organization", "phase", "commitment_count"].join("\t")
    expect(lines.last).to eq [org, phase, commitment_count].join("\t")
  end
end
