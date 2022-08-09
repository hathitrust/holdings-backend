# frozen_string_literal: true
require "spec_helper"
require "data_sources/directory_locator"

RSpec.describe DataSources::DirectoryLocator do
  let(:base) { "/tmp" }
  let(:organization) { "test" }
  let(:year) { Time.new.year.to_s }
  let(:dl) { described_class.new(base, organization) }
  it "#base" do
    expect(dl.base).to eq "#{base}/#{organization}-hathitrust-member-data"
  end
  it "#holdings" do
    expect(dl.holdings).to eq "#{base}/#{organization}-hathitrust-member-data/print holdings"
  end
  it "#holdings_current" do
    expect(dl.holdings_current).to eq "#{base}/#{organization}-hathitrust-member-data/print holdings/#{year}"
  end
  it "#shared_print" do
    expect(dl.shared_print).to eq "#{base}/#{organization}-hathitrust-member-data/shared print"
  end
  it "#analysis" do
    expect(dl.analysis).to eq "#{base}/#{organization}-hathitrust-member-data/analysis"
  end
end
