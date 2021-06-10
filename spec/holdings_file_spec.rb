# frozen_string_literal: true

require "spec_helper"
require "holdings_file"

RSpec.describe HoldingsFile, type: "loaded_file" do
  let(:logger) { double(:logger, info: true) }
  let(:file_path) { Pathname.new("/tmp/holdings_files/testfile.tsv") }
  let(:holdings_file) { described_class.new(file_path) }

  describe "#scrub" do
    it "tries to scrub the file"

    context "when scrub succeeds" do
      it "moves it to seen_files_dir"
      it "logs success"
    end

    context "when scrub fails" do
      it "logs the failure"
      it "leaves the file in place"
    end
  end

  describe "#produced" do
    it "returns the date of the holdings info"
  end

  describe "#source" do
    it "returns the id of the member who created the holdings file"
  end

  describe "#load" do
    let(:fake_loader) { double(:loader) }

    it "tries to load the file" do
      expect(fake_loader).to receive(:load).with(file_path)
      holdings_file.load(loader: fake_loader)
    end


    context "when load succeeds" do
      before(:each) do
        allow(fake_loader)
          .to receive(:load)
          .with(file_path)
      end

      it "logs success" do
        expect(logger).to receive(:info).with(/Finished .* #{file_path}/)
        holdings_file.load(loader: fake_loader)
      end

      it "records the item in the database" do
        holdings_file.load(loader: fake_loader)
        expect(LoadedFile.first.filename).to eq(file_path.to_s)
      end

      it "returns truthy" do
        expect(holdings_file.load(loader: fake_loader)).to be_truthy
      end

      it "moves the file to the loaded directory"
    end

    context "when load raises an exception" do
      before(:each) do
        allow(logger)
          .to receive(:error)

        allow(fake_loader)
          .to receive(:load)
          .and_raise("nasty exception")
      end

      it "logs failure" do
        expect(logger).to receive(:error)
          .with(/Failed.*#{file_path}.*nasty exception/)

        holdings_file.load(loader: fake_loader)
      end

      it "does not record the item in the database" do
        expect { holdings_file.load(loader: fake_loader) }
          .not_to change(LoadedFile, :count)
      end

      it "returns falsey" do
        expect(holdings_file.load(loader: fake_loader)).to be_falsey
      end

      it "leaves the failed file in place"
    end
  end
end
