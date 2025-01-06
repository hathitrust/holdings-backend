# frozen_string_literal: true

require "spec_helper"
require "loader/loaded_file"

RSpec.xdescribe Loader::LoadedFile do
  around(:each) do |example|
    described_class.db.transaction(rollback: :always, auto_savepoint: true) do
      example.run
    end
  end

  it "can persist data about holdings file" do
    expect { build(:loaded_file).save }.to change(described_class, :count).by(1)
  end

  describe "#latest" do
    it "returns the most recently loaded file of a given type" do
      newest = create(:loaded_file, produced: Date.today - 1, type: "test")
      create(:loaded_file, produced: Date.today - 2, type: "test")
      create(:loaded_file, produced: Date.today, type: "anothertest")

      expect(described_class.latest(type: "test").filename).to eq(newest.filename)
    end

    it "returns the most recently loaded file from a given source" do
      newest = create(:loaded_file, produced: Date.today - 1, source: "test")
      create(:loaded_file, produced: Date.today - 2, source: "test")
      create(:loaded_file, produced: Date.today, source: "anothertest")

      expect(described_class.latest(source: "test").filename).to eq(newest.filename)
    end
  end
end
