# frozen_string_literal: true

require "spec_helper"
require "hathifile"

RSpec.describe Hathifile do
  let(:logger) { double(:logger, info: true) }
  let(:hathifile) { described_class.new(Date.parse("2021-04-01")) }
  let(:expected_filename) { Pathname.new("/tmp/hathifiles/hathi_upd_20210401.txt.gz") }

  around(:each) do |example|
    old_hathifile_path = Services.hathifile_path
    old_logger = Services.logger
    Services.register(:hathifile_path) { Pathname.new("/tmp/hathifiles") }
    Services.register(:logger) { logger }
    example.run
    Services.register(:hathifile_path) { old_hathifile_path }
    Services.register(:logger) { old_logger }
  end

  before(:each) do
    HoldingsFile.truncate
  end

  after(:each) do
    HoldingsFile.truncate
  end

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
        expect(HoldingsFile.first.filename).to eq(expected_filename.to_s)
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
        hathifile.load(loader: fake_loader)
        expect(HoldingsFile.count).to eq(0)
      end

      it "returns falsey" do
        expect(hathifile.load(loader: fake_loader)).to be_falsey
      end
    end
  end
end
