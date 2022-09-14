# frozen_string_literal: true

require "spec_helper"
require "reports/rare_uncommitted"
require "loader/cluster_loader"

RSpec.describe Reports::RareUncommitted do
  # with memoize_orgs: false we can manipulate the orgs during testing

  def report(kwargs)
    described_class.new(memoize_orgs: false, **kwargs)
  end

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

  describe "#all_organizations" do
    it "sees no organizations if there are no clusters" do
      expect(report(max_h: 1).all_organizations).to eq []
    end
    it "sees an organization when we add a cluster" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report(max_h: 1).all_organizations).to eq [org1]
    end
    it "sees an organization regardless of commitments" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report(max_h: 1).all_organizations).to eq [org1]
      cluster_tap_save [spc1]
      expect(report(max_h: 1).all_organizations).to eq [org1]
    end
  end

  describe "#sp_organizations" do
    it "sees no sp_organizations if there are no clusters" do
      expect(report(max_h: 1).sp_organizations).to eq []
    end

    it "sees sp_organizations as we add clusters with commitments" do
      expect(report(max_h: 1).sp_organizations).to eq []
      cluster_tap_save [hti1, hol1_org1, spc1]
      expect(report(max_h: 1).sp_organizations).to eq [org1]
    end
  end

  describe "#non_sp_organizations" do
    it "sees nothing if there are no clusters" do
      expect(report(max_h: 1).non_sp_organizations).to eq []
    end

    it "sees organizations that do not have commitments" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report(max_h: 1).non_sp_organizations).to eq [org1]
    end

    it "does not see organizations that have commitments" do
      cluster_tap_save [hti1, hol1_org1, spc1]
      expect(report(max_h: 1).non_sp_organizations).to eq []
    end
  end

  describe "#clusters" do
    it "raises ArgumentError if all of h/sp_h/non_sp_h_count are nil" do
      expect { report.clusters.to_a }.to raise_exception(ArgumentError)
      # All other combos of h/sp_h/non_sp_h_count should, at least, not raise ArgumentError.
      expect(report(max_h: 1).clusters.to_a).to eq []
      expect(report(max_sp_h: 1).clusters.to_a).to eq []
      expect(report(non_sp_h_count: 1).clusters.to_a).to eq []
      expect(report(max_h: 1, max_sp_h: 1, non_sp_h_count: 1).clusters.to_a).to eq []
    end

    it "returns an empty array if there is no data" do
      expect(report(max_sp_h: 2).clusters.to_a.empty?).to be true
    end

    it "rejects a cluster with active commitments" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 1
      cluster_tap_save [spc1] # add commitment to cluster
      expect(report(max_h: 1).clusters.to_a.size).to eq 0
    end

    it "allows clusters with access:allow" do
      cluster_tap_save [hti1_deny, hol1_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 0
    end

    it "rejects clusters with access:deny" do
      cluster_tap_save [hti1_deny, hol1_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 0
    end

    it "allows clusters with mixed access" do
      cluster_tap_save [hti1, hti1_deny, hol1_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 1
    end

    it "allows spm clusters" do
      cluster_tap_save [hti1_deny, hol1_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 0
    end

    it "rejects clusters with format:mpm" do
      mpm = build(:ht_item, :mpm, ocns: [ocn1], access: "allow")
      cluster_tap_save [mpm, hol1_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 0
    end

    it "rejects clusters with format:ser" do
      ser = build(:ht_item, :ser, ocns: [ocn1], access: "allow")
      cluster_tap_save [ser, hol1_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 0
    end

    it "rejects clusters with mixed format" do
      mpm = build(:ht_item, :mpm, ocns: [ocn1], access: "allow")
      ser = build(:ht_item, :ser, ocns: [ocn1], access: "allow")
      cluster_tap_save [mpm, ser, hol1_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 0
      # ... even if that mix contains spm
      cluster_tap_save [hti1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 0
    end

    it "allows a cluster with commitments, if they are deprecated" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 1
      spc1.deprecate(status: "E")
      cluster_tap_save [spc1] # add commitment to cluster
      expect(report(max_h: 1).clusters.to_a.size).to eq 1
    end

    it "allows a cluster with commitments, if their number matches commitment_count" do
      # Commitment count defaults to 0, so for now reject this cluster.
      cluster_tap_save [hti2, hol2_org1, spc2_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 0
      # Set commitment_count to 1 and we allow it.
      expect(report(max_h: 1, commitment_count: 1).clusters.to_a.size).to eq 1
      # Add another commitment to cluster to reject it again.
      cluster_tap_save [spc2_org2]
      expect(report(max_h: 1, commitment_count: 1).clusters.to_a.size).to eq 0
    end

    it "rejects a cluster where cluster_h is gt h" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report(max_h: 1).clusters.to_a.size).to eq 1

      # Increase cluster_h by adding another holding member...
      cluster_tap_save [hol1_org2]
      # ... and max_h:1 will be too low, cluster rejected.
      expect(report(max_h: 1).clusters.to_a.size).to eq 0

      # Raise to max_h:2 and we get the cluster again.
      expect(report(max_h: 2).clusters.to_a.size).to eq 1
    end

    it "rejects a cluster where cluster_sp_h is gt sp_h" do
      cluster_tap_save [hti1, hol1_org1]
      expect(report(max_sp_h: 1).clusters.to_a.size).to eq 1

      # Set up cluster 2, making org1 into a sp_org
      cluster_tap_save [hti2, hol2_org1, spc2_org1]
      expect(report(max_sp_h: 1).sp_organizations.sort).to eq [org1]

      # Still getting the cluster with max_sp_h:1
      expect(report(max_sp_h: 1).clusters.to_a.size).to eq 1

      # Add org2's hol to cluster 1...
      cluster_tap_save [hol1_org2]
      # ... and we're still getting the cluster with max_sp_h:1.
      expect(report(max_sp_h: 1).clusters.to_a.size).to eq 1

      # Add org2 to sp_orgs...
      cluster_tap_save [spc2_org2]
      # ... and now we're NOT getting the cluster with max_sp_h:1
      res = report(max_sp_h: 1).clusters.to_a
      expect(res.size).to eq 0
    end

    it "allows a cluster with non_sp holders, if their number matches non_sp_h_count" do
      # org1 does not have any commitments, so we should get 1 cluster back.
      cluster_tap_save [hti1, hol1_org1]
      expect(report(non_sp_h_count: 1).non_sp_organizations).to eq [org1]
      expect(report(non_sp_h_count: 1).clusters.to_a.size).to eq 1

      # adding a commitment should remove org1 from non_sp_organizations
      cluster_tap_save [hti2, hol2_org1, spc2_org1]
      expect(report(non_sp_h_count: 1).non_sp_organizations).to eq []
      expect(report(non_sp_h_count: 1).clusters.to_a.size).to eq 0

      # adding a second, non_sp, org to the first cluster should bring it back
      cluster_tap_save [hol1_org2]
      expect(report(non_sp_h_count: 1).non_sp_organizations).to eq [org2]
      expect(report(non_sp_h_count: 1).clusters.to_a.size).to eq 1
    end
  end

  describe "#counts" do
    it "no data, no problem" do
      expected = {
        h: {
          0 => {num_clusters: 0, total_items: 0},
          1 => {num_clusters: 0, total_items: 0}
        },
        sp_h: {},
        non_sp_h: {}
      }
      counts = report(max_h: 1).counts
      expect(counts).to eq expected
    end

    it "counts for h" do
      cluster_tap_save [hti1, hol1_org1]

      expected = {
        h: {
          0 => {num_clusters: 0, total_items: 0},
          1 => {num_clusters: 1, total_items: 1}
        },
        sp_h: {},
        non_sp_h: {}
      }
      counts = report(max_h: 1).counts
      expect(counts).to eq expected
    end

    it "counts for sp_h" do
      cluster_tap_save [hti1, hol1_org1, hti2, hol2_org1, spc2_org1]

      expected = {
        h: {},
        sp_h: {
          0 => {num_clusters: 0, total_items: 0},
          1 => {num_clusters: 1, total_items: 1}
        },
        non_sp_h: {}
      }
      counts = report(max_sp_h: 1).counts
      expect(counts).to eq expected
    end

    it "counts for sp_h and h" do
      cluster_tap_save [hti1, hol1_org1, hti2, hol2_org1, spc2_org1]

      expected = {
        h: {
          0 => {num_clusters: 0, total_items: 0},
          1 => {num_clusters: 1, total_items: 1}
        },
        sp_h: {
          0 => {num_clusters: 0, total_items: 0},
          1 => {num_clusters: 1, total_items: 1}
        },
        non_sp_h: {}
      }
      counts = report(max_sp_h: 1, max_h: 1).counts
      expect(counts).to eq expected
    end
  end

  describe "#output_organization" do
    it "returns an array of report rows, incl header" do
      cluster_tap_save [hti1, hol1_org1, hti2, hol2_org1, spc2_org1]
      out_arr = report(organization: org1, max_h: 5).output_organization.to_a
      expect(out_arr).to be_a Array
      expect(out_arr.size).to eq 2
      compare_header = [
        "member_id",
        "local_id",
        "gov_doc",
        "condition",
        "OCN",
        "overlap_ht",
        "overlap_sp"
      ].join("\t")
      header = out_arr.shift
      expect(header).to eq compare_header

      row_data = out_arr.shift.split("\t")
      expect(row_data[0]).to eq "umich"
      expect(row_data[1]).to eq hol1_org1.local_id
      expect(row_data[2]).to eq hol1_org1.gov_doc_flag ? "1" : "0"
      expect(row_data[3]).to eq hol1_org1.condition
      expect(row_data[4]).to eq hol1_org1.ocn.to_s
      puts out_arr
    end
  end
end
