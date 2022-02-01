# frozen_string_literal: true

require "spec_helper"
require "overlap/holding_commitment"
require "clustering/cluster_commitment"

RSpec.describe Overlap::HoldingCommitment do
  let(:ocn_1) { 111 }
  let(:ocn_2) { 222 }
  let(:local_id_1) { "i111" }
  let(:local_id_2) { "i222" }
  let(:org_1) { "umich" }
  let(:org_2) { "smu" }

  def make_cluster(ocn, org, local_id)
    make_htitem(ocn)
    make_holding(ocn, org, local_id)
    make_commitment(ocn, org, local_id)
  end

  def make_htitem(ocn)
    spm = build(:ht_item, :spm, ocns: [ocn])
    Clustering::ClusterHtItem.new(spm).cluster.tap(&:save)
  end

  def make_holding(ocn, org, local_id)
    hol = build(:holding, ocn: ocn, organization: org, local_id: local_id,
          status: "CH", mono_multi_serial: "mono")
    Clustering::ClusterHolding.new(hol).cluster.tap(&:save)
  end

  def make_commitment(ocn, org, local_id)
    com = build(:commitment, ocn: ocn, organization: org, local_id: local_id)
    Clustering::ClusterCommitment.new(com).cluster.tap(&:save)
  end

  before(:each) do
    Cluster.collection.find.delete_many
  end

  it "finds nothing if there are no clusters" do
    overlap = described_class.new(ocn_1)
    expect(overlap.active_commitments.size).to eq 0
    expect(overlap.eligible_holdings.size).to eq 0
  end

  it "finds nothing if there are no clusters that match on ocn" do
    make_cluster(ocn_1, org_1, local_id_1)
    overlap = described_class.new(ocn_2)
    expect(overlap.active_commitments.size).to eq 0
    expect(overlap.eligible_holdings.size).to eq 0
  end

  it "finds the one match" do
    make_cluster(ocn_1, org_1, local_id_1)
    make_cluster(ocn_2, org_2, local_id_2)
    overlap = described_class.new(ocn_1)
    expect(overlap.active_commitments.size).to eq 1
    expect(overlap.eligible_holdings.size).to eq 1
  end

  it "finds more if there is more to find" do
    make_cluster(ocn_1, org_1, local_id_1)
    make_cluster(ocn_1, org_2, local_id_2)
    overlap = described_class.new(ocn_1)
    expect(overlap.active_commitments.size).to eq 2
    expect(overlap.eligible_holdings.size).to eq 2
  end

  it "tests (private) eligible_holding? directly, using status" do
    c = make_holding(ocn_1, org_1, local_id_1)
    overlap = described_class.new(ocn_1)
    expect(overlap.send(:eligible_holding?, c.holdings.first)).to be true
    # Changing status to LM should make the holding ineligible
    c.holdings.first.status = "LM"
    c.save
    overlap = described_class.new(ocn_1)
    expect(overlap.send(:eligible_holding?, c.holdings.first)).to be false
  end

  it "tests (private) eligible_holding? directly, using condition" do
    c = make_holding(ocn_1, org_1, local_id_1)
    overlap = described_class.new(ocn_1)
    expect(overlap.send(:eligible_holding?, c.holdings.first)).to be true
    # Changing condition to BRT should make the holding ineligible
    c.holdings.first.condition = "BRT"
    c.save
    overlap = described_class.new(ocn_1)
    expect(overlap.send(:eligible_holding?, c.holdings.first)).to be false
  end

  it "ignores holdings that arent eligible" do
    c = make_cluster(ocn_1, org_1, local_id_1)
    overlap = described_class.new(ocn_1)
    expect(overlap.eligible_holdings.size).to eq 1
    # Setting status to WD should render the holding ineligible
    c.holdings.first.status = "WD"
    c.save
    overlap = described_class.new(ocn_1)
    expect(overlap.eligible_holdings.size).to eq 0
  end

  it "ignores clusters where there are no ht_items" do
    make_holding(ocn_1, org_1, local_id_1)
    overlap = described_class.new(ocn_1)
    expect(overlap.eligible_holdings.size).to eq 0
  end

  it "ignores clusters where format is mpm" do
    c = make_cluster(ocn_1, org_1, local_id_1)
    overlap = described_class.new(ocn_1)
    expect(overlap.eligible_holdings.size).to eq 1
    # Turning ht_item into an mpm should render the cluster whole ineligible.
    c.ht_items.first.n_enum = "vol 123"
    c.save
    overlap = described_class.new(ocn_1)
    expect(overlap.eligible_holdings.size).to eq 0
  end

  it "ignores clusters where format is ser" do
    c = make_cluster(ocn_1, org_1, local_id_1)
    overlap = described_class.new(ocn_1)
    expect(overlap.eligible_holdings.size).to eq 1
    # Turning ht_item into a ser should render the cluster whole ineligible.
    c.ht_items.first.bib_fmt = "SE"
    c.save
    overlap = described_class.new(ocn_1)
    expect(overlap.eligible_holdings.size).to eq 0
  end

  it "ignores deprecated commitments" do
    replacement = build(:commitment, ocn: ocn_1)
    cluster = make_cluster(ocn_1, org_1, local_id_1)
    overlap = described_class.new(ocn_1)
    expect(overlap.active_commitments.size).to eq 1
    # Deprecating the commitment should remove it from active_commitments.
    cluster.commitments.first.deprecate("E", replacement)
    cluster.save
    expect(cluster.commitments.first.deprecated?).to be true
    overlap = described_class.new(ocn_1)
    expect(overlap.active_commitments.size).to eq 0
  end
end
