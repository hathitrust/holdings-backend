# frozen_string_literal: true

require "spec_helper"
require "holdings_file"

RSpec.describe HoldingsFile do
  around(:each) do |example|
    described_class.db.transaction(rollback: :always, auto_savepoint: true) do
      example.run
    end
  end

  it "can persist data about a holdings file" do
    holding = build(:holdings_file)
    holding.save

    expect(described_class.first[:filename]).to eq(holding.filename)
  end

  describe "#latest" do
    it "returns the most recently loaded file of a given type" do
      newest = create(:holdings_file, produced: Date.today - 1, type: "hathifile")
      create(:holdings_file, produced: Date.today - 2, type: "hathifile")
      create(:holdings_file, produced: Date.today - 1, type: "holding")

      expect(described_class.latest(type: "hathifile").filename).to eq(newest.filename)
    end

    it "returns the most recently loaded file from a given source" do
      newest = create(:holdings_file, produced: Date.today - 1, source: "umich")
      create(:holdings_file, produced: Date.today - 2, source: "umich")
      create(:holdings_file, produced: Date.today - 1, source: "hathitrust")

      expect(described_class.latest(source: "umich").filename).to eq(newest.filename)
    end
  end
end
