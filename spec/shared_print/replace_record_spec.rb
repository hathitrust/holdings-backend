# frozen_string_literal: true

require "spec_helper"
require "shared_print/finder"
require "shared_print/replace_record"

RSpec.describe SharedPrint::ReplaceRecord do
  let(:ocn1) { 1 }
  let(:ocn9) { 9 }
  let(:org1) { "umich" }
  let(:loc1) { "i111" }
  let(:dat1) { DateTime.new(2001, 12, 30) }

  let(:org2) { "yale" }
  let(:loc2) { "i222" }
  let(:obj) { Object.new }
  let(:dat2) { DateTime.new(2002, 12, 30) }

  # Spc 1 & 2 have the same ocn, that's the only similarity
  let(:spc1) { build(:commitment, ocn: ocn1, organization: org1, local_id: loc1, committed_date: dat1) }
  let(:spc2) { build(:commitment, ocn: ocn1, organization: org2, local_id: loc2, committed_date: dat2) }
  let(:spc2_hash) { {ocn: ocn1.to_s, organization: org2, local_id: loc2} }

  # Any new commitments should get this for committed_date.
  let(:jan_first_this_year) { DateTime.new(Time.now.year, 1, 1) }

  def get_deprecated
    SharedPrint::Finder.new(deprecated: true).commitments.to_a
  end

  def get_active
    SharedPrint::Finder.new.commitments.to_a
  end

  # Hooks
  before(:each) do
    Cluster.collection.find.delete_many
  end

  describe "#new(existing: x, replacement: y)" do
    it "requires 2 args (:existing and :replacement)" do
      expect { described_class.new }.to raise_error ArgumentError
    end
    it "allows :existing to be a Clusterable::Commitment" do
      cluster_tap_save(spc1, spc2)
      expect { described_class.new(existing: spc1, replacement: spc2) }.not_to raise_error
      expect { described_class.new(existing: obj, replacement: spc2) }.to raise_error ArgumentError
    end
    it "allows :replacement to be either a hash or a Clusterable::Commitment" do
      cluster_tap_save(spc1, spc2)
      expect { described_class.new(existing: spc1, replacement: spc2_hash) }.not_to raise_error
      expect { described_class.new(existing: spc1, replacement: spc2) }.not_to raise_error
      expect { described_class.new(existing: spc1, replacement: obj) }.to raise_error ArgumentError
    end
  end

  describe "fail gracefully" do
    it "when the :existing commitment cannot be found" do
      cluster_tap_save spc2
      expect {
        described_class.new(existing: spc1, replacement: spc2).apply
      }.to raise_error IndexError
    end
    it "when the :replacement hash cannot be turned into a commitment" do
      cluster_tap_save spc1
      expect {
        described_class.new(existing: spc1, replacement: {}).apply
      }.to raise_error ArgumentError
    end
  end

  describe "#apply" do
    it "replace an active commitment with an existing commitment" do
      # Setup
      cluster_tap_save(spc1, spc2)
      # Pre-check
      expect(SharedPrint::Finder.new.commitments.to_a.size).to eq 2
      expect(spc1.deprecated?).to be false
      # Action
      rep_rec = described_class.new(existing: spc1, replacement: spc2)
      rep_rec.apply
      # Post-check

      deprecated = get_deprecated
      active = get_active
      expect(deprecated.size).to eq 1
      expect(active.size).to eq 1
      expect(deprecated.first.local_id).to eq spc1.local_id
      expect(rep_rec.verify).to be true
      expect(deprecated.first.committed_date).to eq dat1
      expect(active.first.committed_date).to eq dat2
    end
    it "replace a deprecated commitment with an existing commitment" do
      # Setup
      cluster_tap_save(spc1, spc2)
      spc1.deprecate(status: "E")
      # Pre-check
      expect(spc1.deprecated?).to be true
      # Action
      rep_rec = described_class.new(existing: spc1, replacement: spc2)
      rep_rec.apply
      # Post-check
      deprecated = get_deprecated
      active = get_active
      expect(deprecated.size).to eq 1
      expect(active.size).to eq 1
      expect(deprecated.first.local_id).to eq spc1.local_id
      expect(rep_rec.verify).to be true
    end
    it "replace an active commitment with a new commitment" do
      # Setup
      cluster_tap_save spc1
      # Pre-check
      expect(spc1.deprecated?).to be false
      # Action
      rep_rec = described_class.new(existing: spc1, replacement: spc2_hash)
      rep_rec.apply
      # Post-check
      deprecated = get_deprecated
      active = get_active
      expect(deprecated.size).to eq 1
      expect(active.size).to eq 1
      expect(deprecated.first.local_id).to eq spc1.local_id
      expect(rep_rec.verify).to be true
      expect(deprecated.first.committed_date).to eq dat1
      expect(active.first.committed_date).to eq jan_first_this_year
    end
    it "replace a deprecated commitment with a new commitment" do
      # Setup
      cluster_tap_save spc1
      spc1.deprecate(status: "E")
      # Pre-check
      expect(spc1.deprecated?).to be true
      # Action
      rep_rec = described_class.new(existing: spc1, replacement: spc2_hash)
      rep_rec.apply
      # Post-check
      deprecated = get_deprecated
      active = get_active
      expect(deprecated.size).to eq 1
      expect(active.size).to eq 1
      expect(deprecated.first.local_id).to eq spc1.local_id
      expect(rep_rec.verify).to be true
      expect(active.first.committed_date).to eq jan_first_this_year
    end
  end

  describe "#apply_broken" do
    it "copy of 'replace an active commitment with an existing commitment' using broken_apply, left in for science" do
      # Setup
      cluster_tap_save(spc1, spc2)
      # Pre-check
      expect(SharedPrint::Finder.new.commitments.to_a.size).to eq 2
      expect(spc1.deprecated?).to be false
      # Action
      rep_rec = described_class.new(existing: spc1, replacement: spc2)
      rep_rec.apply_broken
      # Post-check
      deprecated = get_deprecated
      active = get_active
      expect(deprecated.size).to eq 1
      # This, active.size == 2, is proof an extra copy gets made,
      # should be 1 like the other tests
      expect(active.size).to eq 2
      expect(deprecated.first.local_id).to eq spc1.local_id
      expect(rep_rec.verify).to be true
    end
  end
end
