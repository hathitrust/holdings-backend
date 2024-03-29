# frozen_string_literal: true

require "spec_helper"
require "loader/hathifile"

RSpec.describe Loader::Hathifile, type: "loaded_file" do
  let(:logger) { double(:logger, info: true) }
  let(:hathifile) { described_class.new(Date.parse("2021-04-02")) }
  let(:expected_filename) { Pathname.new("#{ENV["TEST_TMP"]}/hathifiles/hathi_upd_20210401.txt.gz") }

  it "computes the path for an update file" do
    expect(hathifile.filename).to eq(expected_filename)
  end

  describe "#load" do
    let(:fake_loader) { double(:loader) }

    it "tries to load the file" do
      expect(fake_loader).to receive(:load).with(expected_filename)
      hathifile.load(loader: fake_loader)
    end

    context "when load succeeds" do
      before(:each) do
        allow(fake_loader)
          .to receive(:load)
          .with(expected_filename)
      end

      it "logs success" do
        expect(logger).to receive(:info).with(/Finished .* #{expected_filename}/)
        hathifile.load(loader: fake_loader)
      end

      it "records the item in the database" do
        hathifile.load(loader: fake_loader)
        expect(Loader::LoadedFile.first.filename).to eq(expected_filename.to_s)
      end

      it "returns truthy" do
        expect(hathifile.load(loader: fake_loader)).to be_truthy
      end
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
          .with(/Failed.*#{expected_filename}.*nasty exception/)

        hathifile.load(loader: fake_loader)
      end

      it "does not record the item in the database" do
        expect { hathifile.load(loader: fake_loader) }
          .not_to change(Loader::LoadedFile, :count)
      end

      it "returns falsey" do
        expect(hathifile.load(loader: fake_loader)).to be_falsey
      end
    end
  end
end
