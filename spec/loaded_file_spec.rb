# frozen_string_literal: true

require "spec_helper"
require "loaded_file"

RSpec.describe LoadedFile do
  around(:each) do |example|
    described_class.db.transaction(rollback: :always, auto_savepoint: true) do
      example.run
    end
  end

  it "can persist data about holdings file" do
    file = build(:loaded_file)
    file.save

    expect(described_class.first[:filename]).to eq(file.filename)
  end

  describe "#latest" do
    it "returns the most recently loaded file of a given type" do
      newest = create(:loaded_file, produced: Date.today - 1, type: "hathifile")
      create(:loaded_file, produced: Date.today - 2, type: "hathifile")
      create(:loaded_file, produced: Date.today - 1, type: "holding")

      expect(described_class.latest(type: "hathifile").filename).to eq(newest.filename)
    end

    it "returns the most recently loaded file from a given source" do
      newest = create(:loaded_file, produced: Date.today - 1, source: "umich")
      create(:loaded_file, produced: Date.today - 2, source: "umich")
      create(:loaded_file, produced: Date.today - 1, source: "hathitrust")

      expect(described_class.latest(source: "umich").filename).to eq(newest.filename)
    end
  end
end
