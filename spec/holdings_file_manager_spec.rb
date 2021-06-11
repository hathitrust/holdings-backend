# frozen_string_literal: true

require "spec_helper"
require "holdings_file_manager"
require "tmpdir"
require "fileutils"

RSpec.describe HoldingsFileManager do
  let(:loading_flag) { double(:loading_flag) }
  let(:holdings_file_factory) { double(:holdings_file_factory) }

  around(:each) do |example|
    Dir.mktmpdir do |tmpdir|
      old_holdings_path = Settings.holdings_path
      Settings.holdings_path = tmpdir
      begin
        example.run
      ensure
        Settings.holdings_path = old_holdings_path
      end
    end
  end

  def base_path
    Pathname.new(Settings.holdings_path)
  end

  shared_context "with files" do |n,path,ext|
    let(:files) do
      1.upto(n).map do |i|
        double(:"file#{i}", name: "file#{i}")
      end
    end

    before(:each) do
      FileUtils.mkdir_p(base_path / path)

      files.each do |f|
        filepath = base_path / path / "#{f.name}.#{ext}"

        FileUtils.touch(filepath)
        allow(holdings_file_factory).to receive(:call)
          .with(filepath.to_s)
          .and_return(f)
      end
    end
  end


  let(:loader) do
    described_class.new(holdings_file_factory: holdings_file_factory,
                        loading_flag: loading_flag)
  end

  describe "#try_scrub" do
    include_context "with files", 2, "new", "tsv"

    it "tries to scrub each new file" do
      files.each do |f|
        expect(f).to receive(:scrub).and_return(true)
      end

      loader.try_scrub
    end

    it "continues even if one file fails" do
      allow(files[0]).to receive(:scrub)
        .and_return(false)

      expect(files[1]).to receive(:scrub).and_return(true)

      loader.try_scrub
    end
  end

  describe "#try_load" do

    context "when there are no new files" do
      it "doesn't set the loading flag" do
        expect(loading_flag).not_to receive(:with_lock)
      end
    end

    context "when there are two new files" do
      include_context "with files", 2, "member_data/inst/ready_to_load", "ndj"

      before(:each) do
        allow(loading_flag).to receive(:with_lock).and_yield
      end

      it "tries to load each new file" do
        files.each do |f|
          expect(f).to receive(:load).and_return(true)
        end

        loader.try_load
      end

      it "continues even if one file fails" do
        allow(files[0]).to receive(:load)
          .and_return(false)

        expect(files[1]).to receive(:load)

        loader.try_load
      end
    end
  end
end
