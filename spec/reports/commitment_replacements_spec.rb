# frozen_string_literal: true

require "spec_helper"
require "reports/commitment_replacements"

# is not required higher up like the others clustering classes?
require "clustering/cluster_commitment"

RSpec.xdescribe Reports::CommitmentReplacements do
  def build_h(org, ocn, local_id, status)
    build(
      :holding,
      mono_multi_serial: "mon",
      organization: org,
      ocn: ocn,
      local_id: local_id,
      status: status
    )
  end

  let(:report) { described_class.new }
  let(:ocn1) { 5 }
  let(:ocn2) { 6 }
  # Holdings
  let(:h_ch) { build_h("umich", ocn1, "a123x", "CH") }
  let(:h_lm) { build_h("umich", ocn1, "a123y", "LM") }
  let(:h_wd) { build_h("umich", ocn1, "a123z", "WD") }
  # HT Items
  let(:ht_spm) { build(:ht_item, :spm, ocns: [ocn1]) }
  let(:ht_mpm) { build(:ht_item, :mpm, ocns: [ocn1]) }
  let(:ht_ser) { build(:ht_item, :ser, ocns: [ocn1]) }
  # Commitments
  let(:spc) { build(:commitment, ocn: ocn1, organization: h_ch.organization, local_id: h_ch.local_id) }

  def run(ocns)
    described_class.new(ocns).replacements.to_a
  end

  before(:each) do
    Cluster.collection.find.delete_many
  end

  describe "#header" do
    it "looks like expected" do
      expect(described_class.new([ocn1]).header).to eq(["organization", "oclc_sym", "ocn", "local_id"])
    end
  end
  describe "#for_ocns" do
    it "returns the single matching record" do
      Clustering::ClusterHtItem.new(ht_spm).cluster.tap(&:save)
      Clustering::ClusterHolding.new(h_ch).cluster.tap(&:save)
      rows = run([ocn1, ocn2])
      expect(rows).to eq [["umich", "EYM", 5, "a123x"]]
    end
    it "rejects overlap if there is a commitment-holding match" do
      Clustering::ClusterHtItem.new(ht_spm).cluster.tap(&:save)
      Clustering::ClusterHolding.new(h_ch).cluster.tap(&:save)
      Clustering::ClusterCommitment.new(spc).cluster.tap(&:save)
      rows = run([ocn1])
      expect(rows).to eq []
    end
    it "but includes overlap if the commitment is deprecated" do
      Clustering::ClusterHtItem.new(ht_spm).cluster.tap(&:save)
      Clustering::ClusterHolding.new(h_ch).cluster.tap(&:save)
      spc.deprecate(status: "E")
      Clustering::ClusterCommitment.new(spc).cluster.tap(&:save)
      rows = run([ocn1])
      expect(rows).to eq [["umich", "EYM", 5, "a123x"]]
    end
    it "does a more realistic example" do
      magic_number = 50
      1.upto(magic_number) do |i|
        Clustering::ClusterHolding.new(build_h("umich", i, "i#{i}", "CH")).cluster.tap(&:save)
        Clustering::ClusterHtItem.new(build(:ht_item, :spm, ocns: [i])).cluster.tap(&:save)
      end
      rows = run((1..magic_number).to_a)
      expect(rows.size).to be magic_number
    end
  end
end
