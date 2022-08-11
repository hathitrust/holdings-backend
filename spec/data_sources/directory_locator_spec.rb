# frozen_string_literal: true

require "spec_helper"
require "data_sources/directory_locator"

RSpec.describe DataSources::DirectoryLocator do
  let(:root) { "/tmp/directory_locator_test" }
  let(:org) { "test" }
  let(:year) { Time.new.year.to_s }
  let(:dl) { described_class.new(root, org) }
  let(:suffix) { "hathitrust-member-data" }

  before(:each) do
    FileUtils.rm_rf(root)
  end

  after(:each) do
    FileUtils.rm_rf(root)
  end

  it "#attr_reader" do
    expect(dl.root).to eq root
    expect(dl.organization).to eq org
  end

  it "#base" do
    expect(dl.base).to eq "#{root}/#{org}-#{suffix}"
  end
  it "#holdings" do
    expect(dl.holdings).to eq "#{root}/#{org}-#{suffix}/print holdings"
  end
  it "#holdings_current" do
    expect(dl.holdings_current).to eq "#{root}/#{org}-#{suffix}/print holdings/#{year}"
  end
  it "#shared_print" do
    expect(dl.shared_print).to eq "#{root}/#{org}-#{suffix}/shared print"
  end
  it "#analysis" do
    expect(dl.analysis).to eq "#{root}/#{org}-#{suffix}/analysis"
  end

  it "ensure!" do
    Settings.rclone_config_path = "/tmp/foo.txt"
    FileUtils.touch(Settings.rclone_config_path)
    expect(Dir.exist?(dl.base)).to be false
    expect { dl.ensure! }.to_not raise_error
    expect(Dir.exist?(dl.base)).to be true
  end
end
