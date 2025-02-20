# frozen_string_literal: true

require "spec_helper"
require "shared_print/finder"
require "shared_print/updater"
require "phctl"

RSpec.xdescribe SharedPrint::Updater do
  let(:clu1) { build(:cluster) }
  let(:clu2) { build(:cluster) }
  let(:clu3) { build(:cluster) }
  let(:clu4) { build(:cluster) } # does not have ht_item

  let(:ocn1) { clu1.ocns.first }
  let(:ocn2) { clu2.ocns.first }
  let(:ocn3) { clu3.ocns.first }
  let(:ocn4) { clu4.ocns.first }

  let(:ht1) { build(:ht_item, :spm, ocns: clu1.ocns) }
  let(:ht2) { build(:ht_item, :spm, ocns: clu2.ocns) }
  let(:ht3) { build(:ht_item, :spm, ocns: clu3.ocns) }
  # no ht_4, no cluster for clu4

  let(:org1) { "umich" }
  let(:loc1) { "i111" }
  let(:loc2) { "i222" }
  let(:bib1) { "a" }
  let(:bib2) { "z" }

  # only local_bib_id differs between spc1 and spc2
  let(:spc1) {
    build(
      :commitment,
      ocn: ocn1,
      organization: org1,
      local_id: loc1,
      local_bib_id: bib1,
      policies: []
    )
  }
  let(:spc2) {
    build(
      :commitment,
      ocn: ocn1,
      organization: org1,
      local_id: loc1,
      local_bib_id: bib2,
      policies: ["digitizeondemand"]
    )
  }

  # only local_id differs between upd1 and upd2
  let(:upd1) { {ocn: ocn1, organization: org1, local_id: loc1, local_bib_id: bib2} }
  let(:upd2) { {ocn: ocn1, organization: org1, local_id: loc2, local_bib_id: bib2} }
  let(:upd3) { {ocn: ocn1, organization: org1, local_id: loc1, new_ocn: ocn2} }
  let(:upd4) { {ocn: ocn1, organization: org1, local_id: loc1, policies: "blo"} }
  let(:upd5) { {ocn: ocn1, organization: org1, local_id: loc1, policies: "digitizeondemand, non-repro"} }

  let(:updater) { described_class.new(File::NULL) }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  it "Updates a field on a commitment if Finder finds 1 commitment." do
    cluster_tap_save spc1
    expect(spc1.local_bib_id).to eq "a"
    # Should update local_bib_id on 1 record.
    updater.process_record(upd1)
    # spc1 is stale at this point, so gotta look it up again.
    refresh_spc1 = SharedPrint::Finder.new(ocn: [ocn1]).commitments.to_a.first
    # Confirm they are the same ...
    expect(spc1.uuid).to eq refresh_spc1.uuid
    # ... but that local_bib_id changed.
    expect(refresh_spc1.local_bib_id).to eq "z"
  end

  it "If Finder finds 0 committments, relax search and report finds but do not update." do
    cluster_tap_save spc1
    expect(spc1.local_bib_id).to eq "a"
    # Should not update local_bib_id, because local_id mismatch
    updater.process_record(upd2)
    refresh_spc1 = SharedPrint::Finder.new(ocn: [ocn1]).commitments.to_a.first
    expect(refresh_spc1.local_bib_id).to eq "a"
  end

  it "If Finder finds multiple committments, report finds but do not update." do
    cluster_tap_save(spc1, spc2)
    expect(spc1.local_bib_id).to eq "a"
    # Should not update local_bib_id, because multiple matches
    updater.process_record(upd1)
    refresh_spc1 = SharedPrint::Finder.new(ocn: [ocn1]).commitments.to_a.first
    expect(refresh_spc1.local_bib_id).to eq "a"
  end

  it "strips new_ from :new_ocn and :new_local_id (for identifier updates)" do
    expect(updater.strip_new_from_symbol(:new_ocn)).to eq :ocn
    expect(updater.strip_new_from_symbol(:new_local_id)).to eq :local_id
    expect(updater.strip_new_from_symbol(:new_anything_else)).to eq :new_anything_else
    expect(updater.strip_new_from_symbol(:anything_else)).to eq :anything_else
  end

  it "Full integration test" do
    single_match = build(:commitment, ocn: 1, organization: "umich", local_id: "i1", local_bib_id: "a")
    multi_match_1 = build(:commitment, ocn: 9, organization: "umich", local_id: "i9", local_bib_id: "b")
    multi_match_2 = build(:commitment, ocn: 9, organization: "umich", local_id: "i9", local_bib_id: "c")
    zero_match = build(:commitment, ocn: 999, organization: "yale", local_id: "i999", local_bib_id: "d")
    cluster_tap_save(single_match, multi_match_1, multi_match_2, zero_match)
    # This fixture wants to make 4 updates but only matches the commitment in single_match.
    PHCTL::PHCTL.start(%w[sp update spec/fixtures/test_sp_update_file.tsv])
    # Only single_match should have an updated local_bib_id.
    arr = SharedPrint::Finder.new.commitments.to_a
    expect(arr.map(&:local_bib_id).sort).to eq ["b", "c", "d", "updated"]
  end

  describe "updating ocns" do
    it "can update commitment ocn and move commitment to another cluster" do
      cluster_tap_save(spc1, ht1, ht2)
      expect(Cluster.find_by(ocns: ocn1).commitments.count).to eq 1
      expect(Cluster.find_by(ocns: ocn2).commitments.count).to eq 0
      updater.process_record(upd3)
      expect(Cluster.find_by(ocns: ocn1).commitments.count).to eq 0
      expect(Cluster.find_by(ocns: ocn2).commitments.count).to eq 1
    end

    it "moves to a new cluster if updating to the ocn of another cluster " do
      # Start with a commitment on a cluster with ocns:[ocn1]
      cluster_tap_save(ht1, ht2, spc1)

      original_cluster_id = spc1.cluster._id
      expect(spc1.cluster.ocns).to eq [spc1.ocn]

      # If we update the commitment to ocn2
      updater.process_record(upd3)
      # ...the commitment should move to another cluster

      new_cluster = Cluster.find_by(ocns: [ocn2])
      expect(new_cluster.nil?).to be false
      expect(new_cluster._id).not_to eq original_cluster_id
    end

    it "can update to an ocn on the same cluster" do
      # set up a cluster with ocn1 and ocn2
      resolution = build(:ocn_resolution, variant: ocn1, canonical: ocn2)
      cluster = build(:cluster, ocns: [ocn1, ocn2])
      cluster.save
      cluster.add_ocn_resolutions([resolution])
      expect(cluster.ocns).to eq [ocn1, ocn2]

      # add an spc that has ocn1 (and a matching ht_item)
      cluster_tap_save(spc1, ht1)
      expect(Cluster.count).to eq 1
      expect(Cluster.first.commitments.count).to eq 1

      # Verify that ocn1 and ocn2 lead to the same cluster
      expect(Cluster.find_by(ocns: ocn1)._id).to eq Cluster.find_by(ocns: ocn2)._id

      # Check that the commitment is on the cluster
      expect(Cluster.find_by(ocns: ocn1).commitments.count).to eq 1
      expect(Cluster.find_by(ocns: ocn1).commitments.first.ocn).to eq ocn1

      # Update the spc ocn to another ocn on the same cluster
      # and check that the spc is still there
      updater.process_record(upd3)
      expect(Cluster.find_by(ocns: ocn2).commitments.count).to eq 1
      expect(Cluster.find_by(ocns: ocn1).commitments.first.ocn).to eq ocn2
      expect(Cluster.find_by(ocns: ocn2).commitments.first.ocn).to eq ocn2
    end

    it "cannot update ocn to a cluster that does not exist" do
      # set up a cluster with just a ht_item and commitment with ocn1
      cluster_tap_save(spc1, ht1)
      # Try to update the spc ocn to another ocn that does not have a cluster
      # ... and expect error.
      expect { updater.process_record(upd3) }.to raise_error(
        /no cluster for ocn #{ocn2}/
      )
    end

    it "cannot update ocn to a cluster that does not have any ht_items" do
      # set up a cluster with just a ht_item and commitment with ocn1
      hol2 = build(:holding, ocn: ocn2)
      cluster_tap_save(spc1, ht1, hol2)
      # Try to update the spc ocn to another ocn that does not have a cluster
      # ... and expect error.
      expect { updater.process_record(upd3) }.to raise_error(
        /no htitems on cluster for ocn #{ocn2}/
      )
    end
  end
  describe "updating policies" do
    # Policies are different than the other commitment fields, because it
    # is an array and there are some specific rules about policies
    it "can update policies on a commitment that has empty policies" do
      cluster_tap_save spc1
      # Pre check, make sure policies is empty
      expect(SharedPrint::Finder.new(ocn: [ocn1]).commitments.to_a.first.policies).to eq []
      updater.process_record(upd4)
      # Post check, make sure policies got populated
      expect(SharedPrint::Finder.new(ocn: [ocn1]).commitments.to_a.first.policies).to eq ["blo"]
    end
    it "can update policies on a commitment that already has policies" do
      cluster_tap_save spc2
      # Pre check, make sure policies is populated
      expect(SharedPrint::Finder.new(ocn: [ocn1]).commitments.to_a.first.policies).to eq ["digitizeondemand"]
      updater.process_record(upd4)
      # Post check, make sure policies is updated
      expect(SharedPrint::Finder.new(ocn: [ocn1]).commitments.to_a.first.policies).to eq ["blo"]
    end
    it "cannot update policies to something mutually exclusive" do
      cluster_tap_save spc1
      # Pre check, make sure policies is empty
      expect(SharedPrint::Finder.new(ocn: [ocn1]).commitments.to_a.first.policies).to eq []
      # Post check, upd5 contains non-repro and digitizeondemand which are mutually exclusive
      expect { updater.process_record(upd5) }.to raise_error(ArgumentError, /mutually exclusive/)
    end
  end
end
