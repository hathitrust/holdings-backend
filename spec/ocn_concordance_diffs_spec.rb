# frozen_string_literal: true

require "spec_helper"
require "ocn_concordance_diffs"

RSpec.describe OCNConcordanceDiffs, type: "loaded_file" do
  let(:logger) { double(:logger, info: true) }
  let(:concordance_diffs) { described_class.new(Date.parse("2021-04-02")) }
  let(:expected_filename) { Pathname.new("/tmp/concordance/comm_diff_2021-04-02.txt") }
  let(:expected_adds) { Pathname.new("/tmp/concordance/comm_diff_2021-04-02.txt.adds") }
  let(:expected_deletes) { Pathname.new("/tmp/concordance/comm_diff_2021-04-02.txt.deletes") }

  it "computes the path to concordance diffs" do
    expect(concordance_diffs.filename).to eq(expected_filename)
  end

  describe "#load" do
    let(:fake_loader) { double(:loader, load: true, load_deletes: true) }

    it "tries to load the adds" do
      expect(fake_loader).to receive(:load).with(expected_adds)
      concordance_diffs.load(loader: fake_loader)
    end

    it "tries to load the deletes" do
      expect(fake_loader).to receive(:load_deletes).with(expected_deletes)
      concordance_diffs.load(loader: fake_loader)
    end

    it "logs success" do
      expect(logger).to receive(:info).with(/Finished .* #{expected_filename}/)
      concordance_diffs.load(loader: fake_loader)
    end

    it "records the item in the database" do
      concordance_diffs.load(loader: fake_loader)
      expect(LoadedFile.first.filename).to eq(expected_filename.to_s)
    end

    it "returns truthy" do
      expect(concordance_diffs.load(loader: fake_loader)).to be_truthy
    end

    shared_examples_for "failed file load" do
      it "logs failure" do
        expect(logger).to receive(:error)
          .with(/Failed.*#{expected_filename}.*nasty exception/)

        concordance_diffs.load(loader: fake_loader)
      end

      it "does not record the item in the database" do
        expect { concordance_diffs.load(loader: fake_loader) }
          .not_to change(LoadedFile, :count)
      end

      it "returns falsey" do
        expect(concordance_diffs.load(loader: fake_loader)).to be_falsey
      end
    end

    context "when load_deletes raises an exception" do
      before(:each) do
        allow(logger).to receive(:error)

        allow(fake_loader).to receive(:load_deletes).and_raise("nasty exception")
      end

      it "does not try to load adds" do
        expect(fake_loader).not_to receive(:load)

        concordance_diffs.load(loader: fake_loader)
      end

      it_behaves_like "failed file load"
    end

    context "when load raises an exception" do
      before(:each) do
        allow(logger).to receive(:error)

        allow(fake_loader).to receive(:load).and_raise("nasty exception")
        allow(fake_loader).to receive(:load_deletes).with(expected_deletes)
      end

      it_behaves_like "failed file load"
    end
  end
end
