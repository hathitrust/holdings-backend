# frozen_string_literal: true

require "spec_helper"
require "data_sources/directory_locator"
require "fileutils"

# Conf file must exist, or Utils::FileTransfer raises an error.
FileUtils.touch(Settings.rclone_config_path)

RSpec.describe DataSources::DirectoryLocator do
  let(:org) { "test" }
  let(:root) { ENV["TEST_TMP"] }
  let(:dl) { described_class.new(root, org) }
  let(:year) { Time.new.year.to_s }
  let(:base_x) { "#{root}/test-hathitrust-member-data" }
  let(:holdings_x) { "#{root}/test-hathitrust-member-data/print holdings" }
  let(:sp_x) { "#{root}/test-hathitrust-member-data/shared print" }
  let(:analysis_x) { "#{root}/test-hathitrust-member-data/analysis" }

  before(:each) { FileUtils.touch(Settings.rclone_config_path) }

  describe "attr_reader" do
    it "are set on initialize and readable" do
      expect(dl.root).to eq root
      expect(dl.organization).to eq org
      expect { dl.root = "foo" }.to raise_error NoMethodError
      expect { dl.organization = "bar" }.to raise_error NoMethodError
    end
  end

  describe "the path methods return paths based on root and organization" do
    it "#base" do
      expect(dl.base).to eq base_x
    end
    it "#holdings" do
      expect(dl.holdings).to eq holdings_x
    end
    it "#holdings_current" do
      expect(dl.holdings_current).to eq File.join(holdings_x, year)
    end
    it "#shared_print" do
      expect(dl.shared_print).to eq sp_x
    end
    it "#analysis" do
      expect(dl.analysis).to eq analysis_x
    end
  end

  describe "#ensure!" do
    it "ensures that the directories exist" do
      # The directories don't actually exist ...
      expect(Dir.exist?(dl.base)).to be false
      expect(Dir.exist?(dl.holdings)).to be false
      expect(Dir.exist?(dl.shared_print)).to be false
      expect(Dir.exist?(dl.analysis)).to be false
      # ... until we make them.
      expect { dl.ensure! }.to_not raise_error
      expect(Dir.exist?(dl.base)).to be true
      expect(Dir.exist?(dl.holdings)).to be true
      expect(Dir.exist?(dl.shared_print)).to be true
      expect(Dir.exist?(dl.analysis)).to be true
    end
  end
end
