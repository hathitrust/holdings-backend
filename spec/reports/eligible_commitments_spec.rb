# frozen_string_literal: true

require "spec_helper"
require "reports/eligible_commitments"
require_relative "../../bin/reports/compile_eligible_commitments_report"

# is not required higher up like the others clustering classes?
require "clustering/cluster_commitment"

RSpec.describe Reports::EligibleCommitments do
  def build_h(org, ocn, local_id, status)
    build(
      :holding,
      mono_multi_serial: "mono",
      organization: org,
      ocn: ocn,
      local_id: local_id,
      status: status
    )
  end

  let(:report) { described_class.new }
  let(:ocn1) { 5 }
  let(:ocn2) { 6 }
  # Holdings
  let(:h_ch) { build_h("umich", ocn1, "a123x", "CH") }
  let(:h_lm) { build_h("umich", ocn1, "a123y", "LM") }
  let(:h_wd) { build_h("umich", ocn1, "a123z", "WD") }
  # HT Items
  let(:ht_spm) { build(:ht_item, :spm, ocns: [ocn1]) }
  let(:ht_mpm) { build(:ht_item, :mpm, ocns: [ocn1]) }
  let(:ht_ser) { build(:ht_item, :ser, ocns: [ocn1]) }
  # Commitments
  let(:spc) { build(:commitment, ocn: ocn1) }

  def run(ocns)
    rows = []
    report.for_ocns(ocns) do |row|
      rows << row
    end
    rows
  end

  before(:each) do
    Cluster.collection.find.delete_many
  end

  it "Header looks like expected" do
    expect(report.header).to eq(["organization", "oclc_sym", "ocn", "local_id"])
  end

  it "Returns the single matching record" do
    Clustering::ClusterHtItem.new(ht_spm).cluster.tap(&:save)
    Clustering::ClusterHolding.new(h_ch).cluster.tap(&:save)
    rows = run([ocn1, ocn2])
    expect(rows.count).to eq 1
    expect(rows.first).to eq ["umich", "EYM", 5, "a123x"]
  end

  it "Ignores holdings that arent eligible" do
    Clustering::ClusterHtItem.new(ht_spm).cluster.tap(&:save)
    Clustering::ClusterHolding.new(h_lm).cluster.tap(&:save)
    Clustering::ClusterHolding.new(h_wd).cluster.tap(&:save)
    rows = run([ocn1, ocn2])
    expect(rows.count).to eq 0
  end

  it "Ignores clusters where there are no ht_items" do
    Clustering::ClusterHolding.new(h_ch).cluster.tap(&:save)
    rows = run([ocn1, ocn2])
    expect(rows.count).to eq 0
  end

  it "Ignores clusters where format is mpm" do
    Clustering::ClusterHtItem.new(ht_mpm).cluster.tap(&:save)
    Clustering::ClusterHolding.new(h_ch).cluster.tap(&:save)
    rows_mpm = run([ocn1, ocn2])
    expect(rows_mpm.count).to eq 0
  end

  it "Ignores clusters where format is ser" do
    Clustering::ClusterHtItem.new(ht_ser).cluster.tap(&:save)
    Clustering::ClusterHolding.new(h_ch).cluster.tap(&:save)
    rows_ser = run([ocn1, ocn2])
    expect(rows_ser.count).to eq 0
  end

  it "Keeps track of seen ids" do
    expect(report.we_have_seen?("a")).to be false
    expect(report.we_have_seen?("a")).to be true
    expect(report.we_have_seen?("b")).to be false
  end

  it "Translates organization to oclc_symbol" do
    expect(report.organization_oclc_symbol("umich")).to eq "EYM"
    expect(report.organization_oclc_symbol("upenn")).to eq "PAU"
    expect(report.organization_oclc_symbol("hathitrust")).to eq ""
  end
end
