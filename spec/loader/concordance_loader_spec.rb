# frozen_string_literal: true

require "spec_helper"
require "loader/concordance_loader"

RSpec.describe Loader::ConcordanceLoader do
  around(:each) do |example|
    Services.ht_db.transaction(rollback: :always, auto_savepoint: true) do
      Services.concordance_table.truncate
      example.run
    end
  end

  let(:line) { [1, 2].join("\t") }
  let(:loader) { described_class.new("") }

  describe "#item_from_line" do
    let(:pair) { loader.item_from_line(line) }
    it { expect(pair).to be_a(Array) }
    it { expect(pair.count).to eq 2 }
  end

  describe "#load" do
    it "persists a batch of concordance entries" do
      loader.load([[1, 2], [3, 4]])
      expect(Services[:concordance_table].count).to eq(2)
    end
  end

  describe "#delete" do
    it "deletes a batch of concordance entries" do
      loader.load([[1, 2], [3, 4]])
      loader.delete([[1, 2], [3, 4]])
      expect(Services[:concordance_table].count).to eq(0)
    end
  end
end
