require "shared_print/phase_3_validator"
require "shared_print/phases"
require "shared_print/finder"
require "cluster"

RSpec.xdescribe SharedPrint::Phase3Validator do
  let(:excellent_condition) { "EXCELLENT" }
  let(:acceptable_condition) { "ACCEPTABLE" }
  let(:blo_pol) { "blo" }
  let(:dig_pol) { "digitizeondemand" }
  let(:non_rep_pol) { "non-repro" }
  let(:umich) { "umich" }
  let(:east) { "EAST" }
  let(:fixt) { fixture("phase_3_commitments.tsv") }
  let(:hol) { build(:holding, ocn: spc.ocn, organization: spc.organization) }
  let(:ht) { build(:ht_item, ocns: [spc.ocn]) }
  let(:p3v) { described_class.new(fixt) }
  let(:spc) { build(:commitment, retention_condition: acceptable_condition) }
  let(:finder) { SharedPrint::Finder.new(organization: [spc.organization]) }

  before(:each) do
    Cluster.collection.find.delete_many
  end
  describe "initialize" do
    it "no last_error when freshly inited" do
      expect(p3v.last_error).to be nil
    end
    it "raises if missing settings" do
      orig = Settings.local_report_path
      Settings.local_report_path = nil
      expect { described_class.new(fixt) }.to raise_error(/Missing Settings/)
      Settings.local_report_path = orig
    end
  end
  describe "low-level individual checks called by pass_validation?" do
    it "rejects a commitment if non-valid" do
      expect { p3v.require_valid_commitment(spc) }.to_not raise_error
      spc.committed_date = nil # This makes the commitment non-valid
      expect { p3v.require_valid_commitment(spc) }.to raise_error SharedPrint::Phase3Error
    end
    it "rejects a commitment if no matching cluster" do
      cluster = build(:cluster)
      expect { p3v.require_matching_cluster(cluster) }.to_not raise_error
      expect { p3v.require_matching_cluster(nil) }.to raise_error SharedPrint::Phase3Error
    end
    it "rejects a commitment if no valid cluster" do
      cluster = build(:cluster)
      expect { p3v.require_valid_cluster(cluster) }.to_not raise_error
      cluster.ocns = ["x"] # this makes the cluster non-valid
      expect { p3v.require_valid_cluster(cluster) }.to raise_error SharedPrint::Phase3Error
    end
    it "rejects a commitment if no ht_items in cluster" do
      ht = build(:ht_item, ocns: [spc.ocn])
      cluster_tap_save spc
      cluster = Cluster.find_by(ocns: [spc.ocn])
      expect { p3v.require_cluster_ht_items(cluster) }.to raise_error SharedPrint::Phase3Error
      # Add an ht_item to make it work
      cluster_tap_save ht
      cluster = Cluster.find_by(ocns: [spc.ocn])
      expect { p3v.require_cluster_ht_items(cluster) }.to_not raise_error
    end
    it "requires compatible policies" do
      spc.policies = []
      expect { p3v.require_compatible_policies(spc) }.to_not raise_error
      # add non-repro, should still be good
      spc.policies = [non_rep_pol]
      expect { p3v.require_compatible_policies(spc) }.to_not raise_error
      # add blo, should still be good
      spc.policies = [non_rep_pol, blo_pol]
      expect { p3v.require_compatible_policies(spc) }.to_not raise_error
      # add digitizeondemand should blow it up
      spc.policies = [non_rep_pol, blo_pol, dig_pol]
      expect { p3v.require_compatible_policies(spc) }.to raise_error SharedPrint::Phase3Error
    end
    it "rejects a commitment if no matching holding in cluster" do
      cluster_tap_save spc
      cluster = Cluster.find_by(ocns: [spc.ocn])
      expect { p3v.require_matching_org_holding(cluster, spc.organization) }.to raise_error SharedPrint::Phase3Error
      # Add a holding to make it work

      hol = build(:holding, ocn: spc.ocn, organization: spc.organization)
      cluster_tap_save hol
      cluster = Cluster.find_by(ocns: [spc.ocn])
      expect { p3v.require_matching_org_holding(cluster, spc.organization) }.to_not raise_error
    end
    it "rejects a commitment if no phase 3 policies" do
      spc.policies = []
      expect { p3v.require_phase_3_policies(spc) }.to raise_error SharedPrint::Phase3Error
      spc.policies = [non_rep_pol]
      expect { p3v.require_phase_3_policies(spc) }.to raise_error SharedPrint::Phase3Error
      spc.policies = ["non-circ", blo_pol] # one or the other is ok, both is not ok
      expect { p3v.require_phase_3_policies(spc) }.to raise_error SharedPrint::Phase3Error
    end
    it "allows a commitment with the proper policies" do
      spc.policies = ["non-circ"]
      expect { p3v.require_phase_3_policies(spc) }.to_not raise_error
      spc.policies = [blo_pol]
      expect { p3v.require_phase_3_policies(spc) }.to_not raise_error
    end
    it "requires a valid retention_condition" do
      spc.policies = [blo_pol]
      # should work
      spc.retention_condition = acceptable_condition
      expect { p3v.require_retention_condition(spc) }.to_not raise_error
      # should work
      spc.retention_condition = excellent_condition
      expect { p3v.require_retention_condition(spc) }.to_not raise_error
      # should not
      spc.retention_condition = ""
      expect { p3v.require_retention_condition(spc) }.to raise_error SharedPrint::Phase3Error
    end
  end
  describe "pass_validation? itself" do
    it "validates a commitment that satisfies all the checks" do
      ht = build(:ht_item, ocns: [spc.ocn])
      hol = build(:holding, ocn: spc.ocn, organization: spc.organization)
      cluster_tap_save(ht, hol)
      spc.policies = [blo_pol]
      expect(p3v.pass_validation?(spc)).to be true
      expect(p3v.last_error).to be nil
    end
    it "allows DIGITIZEONDEMAND if mixed with required ph3 policy/ies" do
      ht = build(:ht_item, ocns: [spc.ocn])
      hol = build(:holding, ocn: spc.ocn, organization: spc.organization)
      cluster_tap_save(ht, hol)
      spc.policies = [blo_pol, dig_pol]
      expect(p3v.pass_validation?(spc)).to be true
    end
    it "does not allow DIGITIZEONDEMAND mixed with NON-REPRO" do
      ht = build(:ht_item, ocns: [spc.ocn])
      hol = build(:holding, ocn: spc.ocn, organization: spc.organization)
      cluster_tap_save(ht, hol)
      spc.policies = [blo_pol, non_rep_pol, dig_pol]
      expect(p3v.pass_validation?(spc)).to be false
      expect(p3v.last_error.message).to match(/mutually exclusive policies/)
    end
    it "reports any raised errors" do
      ht = build(:ht_item, ocns: [spc.ocn])
      hol = build(:holding, ocn: spc.ocn, organization: spc.organization)
      cluster_tap_save(ht, hol)
      spc.policies = [] # this should raise something
      expect(p3v.pass_validation?(spc)).to be false
      expect(p3v.last_error.message).to match(/Required policies mismatch/)
    end
  end
  describe "load_one" do
    it "loads a commitment with the proper phase and date" do
      # Add a ht_item, a holding, and a policy or the commitment won't be valid.
      cluster_tap_save(
        build(:ht_item, ocns: [spc.ocn]),
        build(:holding, ocn: spc.ocn, organization: spc.organization)
      )
      spc.policies = [blo_pol]
      # Load it and expect success.
      p3v.load_one(spc)
      # Post-check: no errors, 1 commitment with proper phase and date.
      expect(p3v.last_error).to be_nil
      expect(finder.commitments.count).to eq 1
      expect(finder.commitments.first.phase).to eq SharedPrint::Phases::PHASE_3
      expect(finder.commitments.first.committed_date).to eq SharedPrint::Phases::PHASE_3_DATE
    end
  end
  describe "retention_condition" do
    it "works" do
      # Save a cluster with item + holding ...
      ht = build(:ht_item, ocns: [spc.ocn])
      hol = build(:holding, ocn: spc.ocn, organization: spc.organization)
      cluster_tap_save(ht, hol)
      # set up a matching valid commitment
      spc.policies = [blo_pol]
      spc.retention_condition = excellent_condition
      expect(p3v.pass_validation?(spc)).to be true
      expect(p3v.last_error).to be nil
      # If we load the commitment, we expect to find it.
      p3v.load_one(spc)
      expect(finder.commitments.first.retention_condition).to eq excellent_condition
    end
  end

  describe "run" do
    it "validates and loads records from a file" do
      # Setup, need there to be items and holdings for 2 of the commitments
      # (so that we get a warning from validator about the third)
      [2, 3].each do |ocn|
        cluster_tap_save(
          build(:ht_item, ocns: [ocn]),
          build(:holding, ocn: ocn, organization: umich)
        )
      end
      # Check that 2 commitments were loaded
      expect { p3v.run }.to change { cluster_count(:commitments) }.by(2)
      # And that we got an error from the third
      expect(p3v.last_error).to be_a SharedPrint::Phase3Error
      expect(p3v.last_error.message).to match(/Commitment has no matching cluster/)
      # And that we got a log file out of it
      expect(File.exist?(p3v.log.path)).to be true
    end
  end

  describe "handling optional other_commitments column" do
    # other_commitments is an optional column that contains 2 values
    # or is empty. The values are analyzed as other_program & other_retention_date
    # and comes as a string like "program_name:YYYY-MM-DD"
    # that need to be parsed out and stored separately.
    # The heavy lifting happens in Loader::SharedPrintLoader
    before(:each) do
      # setting up the same htitem and holding for a matching commitment
      ocn = 3
      htitem = build(:ht_item, ocns: [ocn])
      holding = build(:holding, ocn: ocn, organization: umich)
      cluster_tap_save(htitem, holding)
      spc.organization = umich
      spc.ocn = ocn
      spc.policies = [blo_pol]
    end
    it "accepts a commitment with a proper other_commitments" do
      spc.other_program = east
      spc.other_retention_date = DateTime.parse("2099-09-09")
      pass = p3v.pass_validation?(spc)
      expect(pass).to be true
      expect(p3v.last_error).to be nil
    end
    it "error if other_retention_date is set & other_program is nil" do
      # setting other_retention_date but not other_program
      # should result in failed validation
      spc.other_retention_date = DateTime.parse("2099-09-09")
      pass = p3v.pass_validation?(spc)
      expect(pass).to be false
      expect(p3v.last_error.to_s).to match(/cannot be set if other_program is nil/)
    end
    it "error if other_program is set & other_retention_date is nil" do
      # setting other_program but not other_retention_date
      # should result in failed validation
      spc.other_program = east
      pass = p3v.pass_validation?(spc)
      expect(pass).to be false
      expect(p3v.last_error.to_s).to match(/cannot be set if other_retention_date is nil/)
    end
    it "accepts a commitment with no other_commitments" do
      # setting other_program but not other_retention_date
      # should result in failed validation
      pass = p3v.pass_validation?(spc)
      expect(pass).to be true
      expect(p3v.last_error).to be nil
    end
  end
  describe "committed_date" do
    it "should default to PHASE_3_DATE for phase 3 commitments" do
      # Set up clusters
      [2, 3].each do |ocn|
        cluster_tap_save(
          build(:ht_item, ocns: [ocn]),
          build(:holding, ocn: ocn, organization: umich)
        )
      end
      p3v.run
      p3_date = DateTime.parse(SharedPrint::Phases::PHASE_3_DATE)
      # All p3 commitments should have the p3 date
      expect(Cluster.first.commitments.first.committed_date).to eq p3_date
      expect(Cluster.last.commitments.first.committed_date).to eq p3_date
    end
  end
end
