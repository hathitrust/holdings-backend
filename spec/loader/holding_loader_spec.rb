# frozen_string_literal: true

require "spec_helper"
require "loader/holding_loader"

RSpec.xdescribe Loader::HoldingLoader do
  let(:uuid) { SecureRandom.uuid }
  let(:line) do
    [
      "123", # OCN
      "456", # BIB
      "umich", # MEMBER_ID
      "", # STATUS
      "", # CONDITION
      "2020-01-01", # DATE
      "", # ENUM_CHRON
      "spm", # TYPE
      "", # ISSN
      "", # N_ENUM
      "", # N_CHRON
      "", # GOV_DOC
      uuid
    ].join("\t")
  end

  describe "#item_from_line" do
    let(:holding) { described_class.for(".tsv").item_from_line(line) }

    it { expect(holding).to be_a(Clusterable::Holding) }
    it { expect(holding.ocn).to eq 123 }
    it { expect(holding.organization).to eq "umich" }
    it { expect(holding.uuid).to eq uuid }
  end

  describe "#load" do
    before(:each) { Cluster.each(&:delete) }

    it "persists a batch of holdings" do
      holding1 = build(:holding)
      holding2 = build(:holding, ocn: holding1.ocn)

      described_class.new.load([holding1, holding2])

      expect(Cluster.count).to eq(1)
      expect(Cluster.first.holdings.count).to eq(2)
    end
  end
end
