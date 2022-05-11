# frozen_string_literal: true

require "spec_helper"
require "reports/rare_uncommitted"
require "loader/cluster_loader"

RSpec.describe Reports::RareUncommitted do
  # with memoize_orgs: false we can manipulate the orgs during testing
  let(:report) { described_class.new(memoize_orgs: false) }

  let(:ocn1) { 1 }
  let(:ocn2) { 2 }
  let(:org1) { "umich" }
  let(:org2) { "smu" }
  let(:loc1) { "i111" }

  # Cluster 1
  let(:hti1) { build(:ht_item, :spm, ocns: [ocn1], access: "allow") }
  let(:hti1_deny) { build(:ht_item, :spm, ocns: [ocn1], access: "deny") }
  let(:hol1_org1) { build(:holding, ocn: ocn1, local_id: loc1, organization: org1) }
  let(:hol1_org2) { build(:holding, ocn: ocn1, local_id: loc1, organization: org2) }
  let(:spc1) { build(:commitment, ocn: ocn1, organization: org1, local_id: loc1) }

  # Cluster 2
  let(:hti2) { build(:ht_item, :spm, ocns: [ocn2], access: "allow") }
  let(:hol2_org1) { build(:holding, ocn: ocn2, local_id: loc1, organization: org1) }
  let(:hol2_org2) { build(:holding, ocn: ocn2, local_id: loc1, organization: org2) }
  let(:spc2_org1) { build(:commitment, ocn: ocn2, organization: org1, local_id: loc1) }
  let(:spc2_org2) { build(:commitment, ocn: ocn2, organization: org2, local_id: loc1) }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  describe "#sp_organizations" do
    it "sees no sp_organizations if there are no clusters" do
      expect(report.sp_organizations).to eq []
    end

    it "sees sp_organizations as we add clusters with commitments" do
      expect(report.sp_organizations).to eq []
      cluster_tap_save [hti1, hol1_org1, spc1]
      expect(report.sp_organizations).to eq [org1]
    end
  end

  describe "#run" do
    it "raises ArgumentError unless given h and/or sph" do
      expect { report.run.to_a }.to raise_exception(ArgumentError)
      expect(report.run(h: 1, sph: nil).to_a).to eq []
      expect(report.run(h: nil, sph: 1).to_a).to eq []
      expect(report.run(h: 1, sph: 1).to_a).to eq []
    end

    it "returns an empty array if there is no data" do
      expect(report.run(sph: 2).to_a.empty?).to be true
    end

    it "rejects a cluster with active commitments" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report.run(h: 1).to_a.size).to eq 1
      cluster_tap_save [spc1] # add commitment to cluster
      expect(report.run(h: 1).to_a.size).to eq 0
    end

    it "allows clusters with access:allow" do
      cluster_tap_save [hti1_deny, hol1_org1]
      expect(report.run(h: 1).to_a.size).to eq 0
    end

    it "rejects clusters with access:deny" do
      cluster_tap_save [hti1_deny, hol1_org1]
      expect(report.run(h: 1).to_a.size).to eq 0
    end

    it "allows clusters with mixed access" do
      cluster_tap_save [hti1, hti1_deny, hol1_org1]
      expect(report.run(h: 1).to_a.size).to eq 1
    end

    it "allows spm clusters" do
      cluster_tap_save [hti1_deny, hol1_org1]
      expect(report.run(h: 1).to_a.size).to eq 0
    end

    it "rejects clusters with format:mpm" do
      mpm = build(:ht_item, :mpm, ocns: [ocn1], access: "allow")
      cluster_tap_save [mpm, hol1_org1]
      expect(report.run(h: 1).to_a.size).to eq 0
    end

    it "rejects clusters with format:ser" do
      ser = build(:ht_item, :ser, ocns: [ocn1], access: "allow")
      cluster_tap_save [ser, hol1_org1]
      expect(report.run(h: 1).to_a.size).to eq 0
    end

    it "rejects clusters with mixed format" do
      mpm = build(:ht_item, :mpm, ocns: [ocn1], access: "allow")
      ser = build(:ht_item, :ser, ocns: [ocn1], access: "allow")
      cluster_tap_save [mpm, ser, hol1_org1]
      expect(report.run(h: 1).to_a.size).to eq 0
      # ... even if that mix contains spm
      cluster_tap_save [hti1]
      expect(report.run(h: 1).to_a.size).to eq 0
    end

    it "allows a cluster with commitments, if they are deprecated" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report.run(h: 1).to_a.size).to eq 1
      spc1.deprecate(status: "E")
      cluster_tap_save [spc1] # add commitment to cluster
      expect(report.run(h: 1).to_a.size).to eq 1
    end

    it "rejects a cluster where cluster_h is gt h" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report.run(h: 1).to_a.size).to eq 1

      # Increase cluster_h by adding another holding member...
      cluster_tap_save [hol1_org2]
      # ... and h:1 will be too low, cluster rejected.
      expect(report.run(h: 1).to_a.size).to eq 0

      # Raise to h:2 and we get the cluster again.
      expect(report.run(h: 2).to_a.size).to eq 1
    end

    it "rejects a cluster where cluster_sph is gt sph" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report.run(sph: 1).to_a.size).to eq 1

      # Set up cluster 2, making org1 into a sp_org
      cluster_tap_save [hti2, hol2_org1, spc2_org1]
      expect(report.sp_organizations.sort).to eq [org1]

      # Still getting the cluster with sph:1
      expect(report.run(sph: 1).to_a.size).to eq 1

      # Add org2's hol to cluster 1...
      cluster_tap_save [hol1_org2]
      # ... and we're still getting the cluster with sph:1.
      expect(report.run(sph: 1).to_a.size).to eq 1

      # Add org2 to sp_orgs...
      cluster_tap_save [spc2_org2]
      # ... and now we're NOT getting the cluster with sph:1
      res = report.run(sph: 1).to_a
      expect(res.size).to eq 0
    end
  end

  describe "#counts" do
    it "no data, no problem" do
      expected = {
        h: {
          0 => {num_clusters: 0, total_items: 0},
          1 => {num_clusters: 0, total_items: 0}
        },
        sph: {}
      }
      counts = report.counts(h: 1)
      expect(counts).to eq expected
    end

    it "counts for h" do
      cluster_tap_save [hti1, hol1_org1]

      expected = {
        h: {
          0 => {num_clusters: 0, total_items: 0},
          1 => {num_clusters: 1, total_items: 1}
        },
        sph: {}
      }
      counts = report.counts(h: 1)
      expect(counts).to eq expected
    end

    it "counts for sph" do
      cluster_tap_save [hti1, hol1_org1, hti2, hol2_org1, spc2_org1]

      expected = {
        h: {},
        sph: {
          0 => {num_clusters: 0, total_items: 0},
          1 => {num_clusters: 1, total_items: 1}
        }
      }
      counts = report.counts(sph: 1)
      expect(counts).to eq expected
    end

    it "counts for sph and h" do
      cluster_tap_save [hti1, hol1_org1, hti2, hol2_org1, spc2_org1]

      expected = {
        h: {
          0 => {num_clusters: 0, total_items: 0},
          1 => {num_clusters: 1, total_items: 1}
        },
        sph: {
          0 => {num_clusters: 0, total_items: 0},
          1 => {num_clusters: 1, total_items: 1}
        }
      }
      counts = report.counts(sph: 1, h: 1)
      expect(counts).to eq expected
    end
  end
end
