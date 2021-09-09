# frozen_string_literal: true

require "spec_helper"
require "scrub/max_ocn"
require "fileutils"

RSpec.describe Scrub::MaxOcn do
  let(:loc) { described_class.memo_loc }

  before(:each) do
    FileUtils.rm(loc, force: true)
  end

  it "starts with a clean slate" do
    expect(File.exist?(loc)).to be(false)
  end

  it "fetches and stores a value if there is no file present" do
    expect(File.exist?(loc)).to be(false)
    smo = described_class.new(mock: true)
    ocn = smo.ocn
    expect(File.exist?(loc)).to be(true)
    expect(ocn).to eq(123)
  end

  it "fetches and stores a new value if the existing is too old" do
    expect(File.exist?(loc)).to be(false)
    smo = described_class.new(mock: true, age_limit: 1)
    smo.ocn
    mtime1 = File.stat(loc).mtime.to_i
    sleep 2
    smo.ocn
    mtime2 = File.stat(loc).mtime.to_i
    expect(mtime2).to be > mtime1
  end

  it "reuses stored value if the existing is within age limit" do
    expect(File.exist?(loc)).to be(false)
    smo = described_class.new(mock: true, age_limit: 10)
    smo.ocn
    mtime1 = File.stat(loc).mtime.to_i
    sleep 1
    smo.ocn
    mtime2 = File.stat(loc).mtime.to_i
    expect(mtime2).to eq(mtime1)
  end
end
