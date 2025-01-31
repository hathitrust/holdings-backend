# frozen_string_literal: true

require "spec_helper"
require "frequency_table"

RSpec.describe FrequencyTable do
  include_context "with tables for holdings"

  let(:ft) { described_class.new }
  let(:ht1) {
    build(
      :ht_item,
      :spm,
      ocns: [5],
      access: "deny",
      rights: "ic",
      collection_code: "MIU"
    )
  }
  let(:ht2) {
    build(
      :ht_item,
      :spm,
      ocns: [5, 6],
      access: "deny",
      rights: "ic",
      collection_code: "PU"
    )
  }

  before(:each) do
    Cluster.each(&:delete)
    Cluster.create(ocns: ht2.ocns)
    insert_htitem ht1
    insert_htitem ht2
  end

  describe ".new" do
    it "creates a `FrequencyTable`" do
      expect(ft).to be_a(FrequencyTable)
    end
  end

  describe "#organizations" do
    it "returns empty Array when initialized" do
      expect(ft.organizations).to eq([])
    end

    it "returns each org in the cluster" do
      ft.add_ht_item ht1
      ft.add_ht_item ht2
      expect(ft.organizations).to eq([:umich, :upenn])
    end
  end

  describe "#[]" do
    it "returns empty Array for unknown organization" do
      ft.add_ht_item ht1
      ft.add_ht_item ht2
      expect(ft[organization: "no such organization", format: :spm]).to eq({})
    end

    it "returns empty Array for unknown format" do
      ft.add_ht_item ht1
      ft.add_ht_item ht2
      expect(ft[organization: :umich, format: :no_such_format]).to eq({})
    end

    it "returns an Array of statistics when available" do
      ft.add_ht_item ht1
      ft.add_ht_item ht2
      expect(ft[organization: :umich, format: :spm]).to eq({1 => 1})
      expect(ft[organization: :upenn, format: :spm]).to eq({1 => 1})
    end
  end

  describe "#serialize" do
    it "returns the expected String" do
      ft.add_ht_item ht1
      ft.add_ht_item ht2
      expected = <<~END.strip
        umich	{"spm":{"1":1}}
        upenn	{"spm":{"1":1}}
      END
      expect(ft.serialize).to eq(expected)
    end
  end
end
