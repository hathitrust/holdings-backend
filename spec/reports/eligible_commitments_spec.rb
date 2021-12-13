# frozen_string_literal: true

require "spec_helper"
require "reports/eligible_commitments"

RSpec.describe "EligibleCommitments" do
  let(:report) { Reports::EligibleCommitments.new }
  let(:ocn1) { 5 }
  let(:ocn2) { 6 }
  let(:h_ch) { build(:holding, ocn: ocn1, mono_multi_serial: "mono", status: "CH") }
  let(:h_lm) { build(:holding, ocn: ocn1, mono_multi_serial: "mono", status: "LM") }
  let(:h_wd) { build(:holding, ocn: ocn1, mono_multi_serial: "mono", status: "WD") }
  let(:ht_spm) { build(:ht_item, :spm, ocns: [ocn1], billing_entity: h_ch.organization) }
  let(:ht_mpm) { build(:ht_item, :mpm, ocns: [ocn1], billing_entity: h_ch.organization) }
  let(:ht_ser) { build(:ht_item, :ser, ocns: [ocn1], billing_entity: h_ch.organization) }
  let(:spc) { build(:commitment, ocn: ocn1, organization: h_ch.organization) }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  it "has a header and it looks like this" do
    expect(report.header).to eq(["ocn", "commitments"])
  end

  it "runs" do
    Clustering::ClusterHtItem.new(ht_spm).cluster.tap(&:save)
    Clustering::ClusterHolding.new(h_ch).cluster.tap(&:save)
    expect(report.for_ocns([ocn1, ocn2])).to be true
  end

  it "wants to know if a clusterable::holding can get its own cluster" do
    c1 = Clustering::ClusterHtItem.new(ht_spm).cluster.tap(&:save)
    c2 = Clustering::ClusterHolding.new(h_ch).cluster.tap(&:save)
    expect(c1).to be_a Cluster
    expect(c1).to eq c2
    expect(c2.holdings.first.cluster).to eq c2
  end
end
