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
    expect([overlap.commitments.size, overlap.holdings.size, overlap.matched_pairs.size])
      .to eq [0, 0, 0]
    expect([overlap.holdings_h, overlap.commitments_h]).to eq [0, 0]
  end

  it "finds nothing if there are no _matching_ clusters" do
    make_cluster(ocn_1, org_1, local_id_1)
    overlap = described_class.new(ocn_2)
    expect([overlap.commitments.size, overlap.holdings.size, overlap.matched_pairs.size])
      .to eq [0, 0, 0]
    expect([overlap.holdings_h, overlap.commitments_h]).to eq [0, 0]
  end

  it "finds the one match" do
    make_cluster(ocn_1, org_1, local_id_1)
    make_cluster(ocn_2, org_2, local_id_2)
    overlap = described_class.new(ocn_1)
    expect([overlap.commitments.size, overlap.holdings.size, overlap.matched_pairs.size])
      .to eq [1, 1, 1]
    expect([overlap.holdings_h, overlap.commitments_h]).to eq [1, 1]
  end

  it "finds all matching pairs" do
    make_cluster(ocn_1, org_1, local_id_1)
    make_cluster(ocn_1, org_2, local_id_2)
    overlap = described_class.new(ocn_1)
    expect([overlap.commitments.size, overlap.holdings.size, overlap.matched_pairs.size])
      .to eq [2, 2, 2]
    expect([overlap.holdings_h, overlap.commitments_h]).to eq [2, 2]
  end

  it "increases the *_h values when distinct orgs go up" do
    make_cluster(ocn_1, org_1, local_id_1)

    # same org, no increase
    make_holding(ocn_1, org_1, local_id_2)
    make_commitment(ocn_1, org_1, local_id_2)
    overlap = described_class.new(ocn_1)
    expect([overlap.holdings_h, overlap.commitments_h]).to eq [1, 1]

    # new org, DO increase
    make_holding(ocn_1, org_2, local_id_1)
    make_commitment(ocn_1, org_2, local_id_1)
    overlap = described_class.new(ocn_1)
    expect([overlap.holdings_h, overlap.commitments_h]).to eq [2, 2]
  end
end
