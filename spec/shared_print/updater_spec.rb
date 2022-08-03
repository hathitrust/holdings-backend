# frozen_string_literal: true

require "spec_helper"
require "shared_print/finder"
require "shared_print/updater"
require "phctl"

RSpec.describe SharedPrint::Updater do
  let(:ocn1) { 1 }
  let(:org1) { "umich" }
  let(:loc1) { "i111" }
  let(:loc2) { "i222" }
  let(:bib1) { "a" }
  let(:bib2) { "z" }

  # only local_bib_id differs between spc1 and spc2
  let(:spc1) {
    build(:commitment, ocn: ocn1, organization: org1, local_id: loc1, local_bib_id: bib1)
  }
  let(:spc2) {
    build(:commitment, ocn: ocn1, organization: org1, local_id: loc1, local_bib_id: bib2)
  }

  # only local_id differs between upd1 and upd2
  let(:upd1) { {ocn: ocn1, organization: org1, local_id: loc1, local_bib_id: bib2} }
  let(:upd2) { {ocn: ocn1, organization: org1, local_id: loc2, local_bib_id: bib2} }

  let(:updater) { described_class.new("/dev/null") }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  it "Updates a field on a commitment if Finder finds 1 commitment." do
    cluster_tap_save [spc1]
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
    cluster_tap_save [spc1]
    expect(spc1.local_bib_id).to eq "a"
    # Should not update local_bib_id, because local_id mismatch
    updater.process_record(upd2)
    refresh_spc1 = SharedPrint::Finder.new(ocn: [ocn1]).commitments.to_a.first
    expect(refresh_spc1.local_bib_id).to eq "a"
  end

  it "If Finder finds multiple committments, report finds but do not update." do
    cluster_tap_save [spc1, spc2]
    expect(spc1.local_bib_id).to eq "a"
    # Should not update local_bib_id, because multiple matches
    updater.process_record(upd1)
    refresh_spc1 = SharedPrint::Finder.new(ocn: [ocn1]).commitments.to_a.first
    expect(refresh_spc1.local_bib_id).to eq "a"
  end

  it "Full integration test" do
    single_match = build(:commitment, ocn: 1, organization: "umich", local_id: "i1", local_bib_id: "a")
    multi_match_1 = build(:commitment, ocn: 9, organization: "umich", local_id: "i9", local_bib_id: "b")
    multi_match_2 = build(:commitment, ocn: 9, organization: "umich", local_id: "i9", local_bib_id: "c")
    zero_match = build(:commitment, ocn: 999, organization: "yale", local_id: "i999", local_bib_id: "d")
    cluster_tap_save [single_match, multi_match_1, multi_match_2, zero_match]
    # This fixture wants to make 4 updates but only matches the commitment in single_match.
    PHCTL::PHCTL.start(%w[sp update spec/fixtures/test_sp_update_file.tsv])
    # Only single_match should have an updated local_bib_id.
    arr = SharedPrint::Finder.new.commitments.to_a
    expect(arr.map(&:local_bib_id).sort).to eq ["b", "c", "d", "updated"]
  end
end
