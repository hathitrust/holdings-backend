# frozen_string_literal: true

require "spec_helper"
require "reports/holdings_by_date_report"

RSpec.describe Reports::HoldingsByDateReport do
  let(:ocn1) { 1 }
  let(:ocn2) { 2 }
  let(:org1) { "umich" }
  let(:org2) { "smu" }
  let(:spm) { "spm" }
  let(:mpm) { "mpm" }
  let(:ser) { "ser" }
  let(:tim1) { Time.new("2001") }
  let(:tim2) { Time.new("2002") }
  let(:rpt) { described_class.new }

  # Leave nothing behind.
  before(:each) do
    FileUtils.rm_f(rpt.outf)
    Cluster.collection.find.delete_many
  end

  after(:all) do
    Cluster.collection.find.delete_many
  end

  # Shorthand for making holdings.
  def bld_hol(ocn, org, mms, tim)
    build(:holding, ocn: ocn, organization: org, mono_multi_serial: mms, date_received: tim)
  end

  it "has a query" do
    expect(rpt.query).to be_a Array
  end
  it "has a header" do
    expect(rpt.header).to eq "organization\tformat\tmax_load_date"
  end
  it "can make an outfile" do
    outf = rpt.outf
    expect(File.exist?(outf)).to be false
    rpt.run
    expect(File.exist?(outf)).to be true
  end
  it "formats a query result to a tab separated line" do
    tn = Time.now
    tn_expect = tn.strftime("%Y")
    res = {"_id" => {"org" => "O", "fmt" => "F"}, "max_date" => tn}
    expect(rpt.to_row(res)).to eq "O\tF\t#{tn_expect}"
  end
  it "gets zero data from an empty db" do
    expect(rpt.data.count).to eq 0
  end
  it "writes an empty report (only header) from an empty db" do
    rpt.run
    lines = File.read(rpt.outf).split("\n")
    expect(lines.count).to be 1
    expect(lines.first).to eq rpt.header
  end
  it "gives data as an enum" do
    expect(rpt.data).to be_a Enumerator
  end
  it "gets data from a populated db" do
    # Add 2 records (different orgs) to db
    cluster_tap_save [
      bld_hol(ocn1, org1, spm, tim1),
      bld_hol(ocn1, org2, spm, tim1)
    ]

    # Get 2 records out
    expect(rpt.data.count).to eq 2

    # Expect the output to be derived from the input
    expect1 = {"_id" => {"fmt" => spm, "org" => org2}, "max_date" => tim1}
    expect2 = {"_id" => {"fmt" => spm, "org" => org1}, "max_date" => tim1}
    # Results are sorted by _id,
    # meaning org2 (smu) comes before org1 (umich)
    res = rpt.data.to_a
    expect(res.first).to eq expect1
    expect(res.last).to eq expect2
  end
  it "reports the max date for a group" do
    # Add 2 records (same org, diff dates) to db
    cluster_tap_save [
      bld_hol(ocn1, org1, spm, tim1),
      bld_hol(ocn2, org1, spm, tim2)
    ]

    # Get 1 record out (because select max, group on org+fmt)
    res = rpt.data
    expect(res.count).to eq 1

    # Expect the max date
    expected = {"_id" => {"fmt" => spm, "org" => org1}, "max_date" => tim2}
    expect(res.first).to eq expected
  end
  it "reports orgs separately" do
    cluster_tap_save [
      bld_hol(ocn1, org1, spm, tim1),
      bld_hol(ocn1, org2, spm, tim1)
    ]
    expect(rpt.data.count).to eq 2
  end
  it "reports mono_multi_serial separately" do
    cluster_tap_save [
      bld_hol(ocn1, org1, spm, tim1),
      bld_hol(ocn1, org1, mpm, tim1)
    ]
    expect(rpt.data.count).to eq 2
  end
  it "ignores ocn for grouping and reporting purposes" do
    cluster_tap_save [
      bld_hol(ocn1, org1, spm, tim1),
      bld_hol(ocn2, org1, spm, tim1)
    ]
    expect(rpt.data.count).to eq 1
  end
  it "writes a report file" do
    cluster_tap_save [
      # org1
      bld_hol(ocn1, org1, spm, tim1),
      bld_hol(ocn1, org1, mpm, tim1),
      bld_hol(ocn1, org1, ser, tim1),
      bld_hol(ocn1, org1, spm, tim2), # should count
      bld_hol(ocn1, org1, mpm, tim2), # should count
      bld_hol(ocn1, org1, ser, tim2), # should count
      # org2
      bld_hol(ocn1, org2, spm, tim1),
      bld_hol(ocn1, org2, mpm, tim1),
      bld_hol(ocn1, org2, ser, tim1),
      bld_hol(ocn1, org2, spm, tim2), # should count
      bld_hol(ocn1, org2, mpm, tim2), # should count
      bld_hol(ocn1, org2, ser, tim2) ## should count
    ]

    expected_report = [
      "organization\tformat\tmax_load_date",
      "smu\tmpm\t2002",
      "smu\tser\t2002",
      "smu\tspm\t2002",
      "umich\tmpm\t2002",
      "umich\tser\t2002",
      "umich\tspm\t2002"
    ]

    rpt.run
    expect(File.read(rpt.outf).split("\n")).to eq expected_report
  end
end
