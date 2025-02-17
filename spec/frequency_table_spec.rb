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

    it "accepts JSON" do
      expect(described_class.new(json: "{}")).to be_a described_class
    end

    it "round-trips JSON" do
      ft.add_ht_item ht1
      ft.add_ht_item ht2
      round_tripped = described_class.new(json: ft.to_json)
      expect(round_tripped.organizations.sort).to eq [:umich, :upenn].sort
      expect(round_tripped.fetch(organization: :umich)).to eq(ft.fetch(organization: :umich))
      expect(round_tripped.fetch(organization: :upenn)).to eq(ft.fetch(organization: :upenn))
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

  describe "#append!" do
    let(:ft1) { described_class.new }
    let(:ft2) { described_class.new }

    it "returns the reciever" do
      expect(ft1.append!(ft2).object_id).to eq(ft1.object_id)
    end

    it "adds organizations" do
      ft1.add_ht_item ht1
      ft2.add_ht_item ht2
      expected_keys = (ft1.organizations + ft2.organizations).uniq.sort
      expect(ft1.append!(ft2).organizations).to eq(expected_keys)
    end

    it "adds counts" do
      ft1.add_ht_item ht1
      ft2.add_ht_item ht1
      ft2.add_ht_item ht2
      expect(ft1.append!(ft2).fetch(organization: :umich, format: :spm, bucket: 1)).to eq(2)
      expect(ft2.fetch(organization: :umich, format: :spm, bucket: 1)).to eq(1)
    end

    it "isolates the receiver from subsequent changes to added table" do
      ft1.add_ht_item ht1
      ft2.add_ht_item ht2
      ft1.append! ft2
      expect(ft2.fetch(organization: :upenn, format: :spm, bucket: 1)).to eq(1)
      ft1.increment(organization: :smu, format: :mpm, bucket: 10)
      ft1.add_ht_item ht2
      # TODO: rewrite especially this test in terms of `increment` and have ft1 initialized from data
      # so it's obvious what is there and what is not (without calling `puts` on the table all the time.
      expect(ft2.fetch(organization: :upenn, format: :spm, bucket: 1)).to eq(1)
      expect(ft2.organizations).not_to include(:smu)
    end
  end

  describe "#+" do
    let(:ft1) { described_class.new }
    let(:ft2) { described_class.new }

    it "returns a new FrequencyTable" do
      ft3 = ft1 + ft2
      expect(ft3).to be_a(described_class)
      expect(ft3.object_id).not_to eq(ft1.object_id)
      expect(ft3.object_id).not_to eq(ft2.object_id)
    end

    it "returns a FrequencyTable with all organizations in the addends" do
      ft1.add_ht_item ht1
      ft2.add_ht_item ht2
      expected_keys = (ft1.organizations + ft2.organizations).uniq.sort
      ft3 = ft1 + ft2
      expect(ft3.organizations).to eq(expected_keys)
    end

    it "returns a FrequencyTable with all counts in the addends" do
      ft1.add_ht_item ht1
      ft2.add_ht_item ht1
      ft2.add_ht_item ht2
      ft3 = ft1 + ft2
      expect(ft3.fetch(organization: :umich, format: :spm, bucket: 1)).to eq(2)
      expect(ft3.fetch(organization: :upenn, format: :spm, bucket: 1)).to eq(1)
    end
  end

  describe "#to_json" do
    it "produces JSON" do
      ft.add_ht_item ht1
      ft.add_ht_item ht2
      expect(ft.to_json).to be_a(String)
    end
  end
end
