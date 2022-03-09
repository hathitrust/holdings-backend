# frozen_string_literal: true

require "spec_helper"
require "shared_print/finder"
require "shared_print/replacer"

RSpec.describe SharedPrint::Replacer do
  let(:loc1) { "i111" }
  let(:loc2) { "i222" }
  let(:ocn1) { 1 }
  let(:org1) { "umich" }
  let(:org2) { "yale" }
  # Spc 1 & 2 have the same ocn, that's the only similarity
  let(:spc1) { build(:commitment, ocn: ocn1, organization: org1, local_id: loc1) }
  let(:spc2) { build(:commitment, ocn: ocn1, organization: org2, local_id: loc2) }
  let(:update_file_path) { "spec/fixtures/test_sp_replace_file.tsv" }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  def get_deprecated
    SharedPrint::Finder.new(deprecated: true).commitments.to_a
  end

  def get_active
    SharedPrint::Finder.new.commitments.to_a
  end

  describe "#run" do
    it "makes SharedPrint::ReplaceRecords from a file and applies them" do
      # Setup
      cluster_tap_save [spc1]
      # Pre-check
      expect(spc1.deprecated?).to be false
      # Action
      described_class.new(update_file_path).run
      # Post-check
      deprecated = get_deprecated
      active = get_active

      expect(deprecated.size).to eq 1
      expect(active.size).to eq 1
      expect(deprecated.first.local_id).to eq spc1.local_id
      expect(active.first.local_id).to eq spc2.local_id
    end
  end
end
