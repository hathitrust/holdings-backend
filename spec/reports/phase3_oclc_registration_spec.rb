# frozen_string_literal: true

require "spec_helper"
require "reports/phase3_oclc_registration"
require "shared_print/phases"

RSpec.describe Reports::Phase3OCLCRegistration do
  let(:org) { "umich" }
  let(:sym) { "FOO" }
  let(:cond) { "ACCEPTABLE" }
  let(:collection_id_foo) { "123" }
  let(:rep) { described_class.new(org) }
  let(:phase_to_date) { SharedPrint::Phases.phase_to_date }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  it "provides a header that looks *just so*" do
    header_cols = rep.hed.split("\t")
    expect(header_cols.size).to eq 14
    expect(header_cols.first).to eq "OCLC"
    # ... yada yada, literally a hardcoded arr, not gonna test too hard
    expect(header_cols.last).to eq "MaterialsSpecified_583$3"
  end
  it "formats commitments into the desired report format" do
    # Setup...

    foo_id = "123"
    com = build(
      :commitment,
      organization: org,
      oclc_sym: sym,
      retention_condition: cond,
      committed_date: SharedPrint::Phases::PHASE_3_DATE
    )
    cols = rep.fmt(com).split("\t", -1) # -1 to keep trailing tabs
    # Expect 14 columns:
    expect(cols.size).to eq 14
    # ... and they look like this:
    expect(cols[0]).to eq com.ocn.to_s
    expect(cols[1]).to eq com.local_id.to_s
    expect(cols[2]).to be_empty
    expect(cols[3]).to eq com.oclc_sym.to_s
    expect(cols[4]).to be_empty
    expect(cols[5]).to eq foo_id # collection_id lookup via fixture file
    expect(cols[6]).to eq "committed to retain"
    expect(cols[7]).to eq "20230131"
    expect(cols[8]).to eq "20421231"
    expect(cols[9]).to eq "ivolume-level"
    expect(cols[10]).to eq "condition reviewed"
    expect(cols[11]).to eq cond
    expect(cols[12]).to be_empty
    expect(cols[13]).to be_empty
  end
  it "only gets the phase 3 commitments" do
    # Setup: Build 9 commitments, same org, different ocns
    comms = []
    1.upto(9) do |i|
      comms << build(
        :commitment,
        ocn: i,
        organization: org,
        oclc_sym: sym,
        retention_condition: cond
      )
    end
    # Set phase 1 for the first 3, phase 2 for the mid 3, phase 3 for the last 3
    comms[0..2].each { |c| c.phase = SharedPrint::Phases::PHASE_1 }
    comms[3..5].each { |c| c.phase = SharedPrint::Phases::PHASE_2 }
    comms[6..8].each { |c| c.phase = SharedPrint::Phases::PHASE_3 }
    cluster_tap_save(*comms) # ... and save.

    # Only expect to see header & the phase 3 commitments in report:
    rep.run
    lines = File.read(rep.output_path).split("\n")
    expect(lines.count).to be 4
    expect(lines[0]).to start_with "OCLC\t"
    expect(lines[1]).to start_with "7\t"
    expect(lines[2]).to start_with "8\t"
    expect(lines[3]).to start_with "9\t"
  end
end
