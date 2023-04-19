require "spec_helper"
require "reports/overlap_report"
require "pathname"

RSpec.describe Reports::OverlapReport do
  let(:org1) { "umich" }
  let(:org2) { "smu" }
  let(:ocn1) { 1 }
  let(:loc1) { "loc_001" }
  let(:c0) { build(:cluster) }
  let(:hol1) { build(:holding, organization: org1, ocn: ocn1, local_id: loc1) }
  let(:hol2) { build(:holding, organization: org2, ocn: ocn1, local_id: loc1) }
  let(:ht1) { build(:ht_item, ocns: [ocn1]) }
  let(:ht2) { build(:ht_item, ocns: [ocn1]) }
  let(:spc1) { build(:commitment, ocn: ocn1, organization: org1) }
  let(:spc2) { build(:commitment, ocn: ocn1, organization: org2) }
  let(:rep_short) { described_class.new(organization: org1, ph: true) }
  let(:rep_long) { described_class.new(organization: org1, ph: true, htdl: true, sp: true) }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  describe "#initialize" do
    it "requires organization, and 1+ of ph/htdl/sp to be true" do
      # Should fail because no org
      expect { described_class.new }.to raise_error(/fix inputs/)
      # Should fail because all ph/htdl/sp are false (by default)
      expect { described_class.new(organization: org1) }.to raise_error(/fix inputs/)
      # Should work
      expect { described_class.new(organization: org1, ph: true) }.not_to raise_error
      expect { described_class.new(organization: org1, htdl: true) }.not_to raise_error
      expect { described_class.new(organization: org1, sp: true) }.not_to raise_error
      # (skipping some parameter permutations)
      expect { rep_long }.not_to raise_error
    end
  end
  describe "#outf_path" do
    it "returns a writable path" do
      p = rep_short.outf_path
      expect { FileUtils.touch(p) }.not_to raise_error
    end
  end
  describe "#header" do
    it "includes the proper cols" do
      expect(rep_short.header).to eq ["ocn", "local_id", "ph_overlap"]
      # Bigger example
      all_cols_rep = described_class.new(organization: org1, ph: true, htdl: true, sp: true)
      expect(all_cols_rep.header)
        .to eq ["ocn", "local_id", "ph_overlap", "htdl_overlap", "sp_overlap"]
    end
  end
  describe "#clusters" do
    it "returns an enumerator for clusters" do
      # Gotta put something in the db or rep_short.clusters.first is nil
      cluster_tap_save [hol1]
      expect(rep_short.clusters).to be_a Enumerator
      expect(rep_short.clusters.first).to be_a Cluster
    end
  end
  describe "#row" do
    it "formats report rows according to settings" do
      expect(rep_short.row(hol1, 1, nil, nil)).to eq [ocn1, loc1, 1]
      expect(rep_long.row(hol1, 1, 2, 3)).to eq [ocn1, loc1, 1, 2, 3]
    end
  end
  describe "#count_cluster_ph" do
    it "counts the number of distinct orgs with holdings in a cluster" do
      # Zero if no holdings (which really shouldn't happen in the first place)
      expect(rep_short.count_cluster_ph(c0)).to eq 0

      # 1 if there is one org with holdings in cluster
      cluster_tap_save([hol1])
      expect(rep_short.count_cluster_ph(Cluster.where(ocns: [ocn1]).first)).to eq 1

      # 2 if there are two orgs with holdings in cluster, ... n
      cluster_tap_save([hol2])
      expect(rep_short.count_cluster_ph(Cluster.where(ocns: [ocn1]).first)).to eq 2
    end
  end
  describe "#count_cluster_htdl" do
    it "counts the number of ht_items in a cluster" do
      rep = described_class.new(organization: org1, htdl: true)
      expect(rep.count_cluster_htdl(c0)).to eq 0

      # 1 if there is one ht_item in cluster
      cluster_tap_save([ht1])
      expect(rep.count_cluster_htdl(Cluster.where(ocns: [ocn1]).first)).to eq 1

      # 2 if there are 2 org ht_items_in cluster in cluster, ... n
      cluster_tap_save([ht2])
      expect(rep.count_cluster_htdl(Cluster.where(ocns: [ocn1]).first)).to eq 2
    end
  end
  describe "#count_cluster_sp" do
    it "counts the number of distinct orgs w commitments in a cluster" do
      rep = described_class.new(organization: org1, sp: true)
      expect(rep.count_cluster_sp(c0)).to eq 0

      # 1 if there is one org w commitment in cluster
      cluster_tap_save([spc1])
      expect(rep.count_cluster_sp(Cluster.where(ocns: [ocn1]).first)).to eq 1

      # 2 if there are 2 orgs w commitment in cluster, ... n
      cluster_tap_save([spc2])
      expect(rep.count_cluster_sp(Cluster.where(ocns: [ocn1]).first)).to eq 2
    end
  end
  describe "#run" do
    it "runs report and outputs to file" do
      # Setup, put some data in the db
      cluster_tap_save [ht1, ht2, hol1, hol2, spc1, spc2]

      # just one field
      rep_short.run
      report_rows = File.read(rep_short.outf_path).split("\n")
      expect(report_rows.count).to eq 2
      expect(report_rows.first).to eq "ocn\tlocal_id\tph_overlap"
      expect(report_rows.last).to eq "1\tloc_001\t2"

      # all fields
      rep_long.run
      report_rows = File.read(rep_long.outf_path).split("\n")
      expect(report_rows.count).to eq 2
      expect(report_rows.first).to eq "ocn\tlocal_id\tph_overlap\thtdl_overlap\tsp_overlap"
      expect(report_rows.last).to eq "1\tloc_001\t2\t2\t2"
    end
  end
end
