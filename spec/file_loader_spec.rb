# frozen_string_literal: true

require "spec_helper"
require "file_loader"

class FakeItem
  def initialize(line)
    @line = line.strip
  end

  def batch_with?(other)
    return unless other

    line == other.line
  end

  attr_reader :line
end

class FakeBatchLoader
  def initialize
    @loaded = []
  end

  def item_from_line(line)
    FakeItem.new(line)
  end

  def load(batch)
    loaded << batch
  end

  attr_reader :loaded
end

RSpec.describe FileLoader do
  let(:fh) do
    StringIO.new(<<~DATA)
      thing1
      thing1
      thing2
    DATA
  end

  let(:batch_loader) { FakeBatchLoader.new }

  let(:file_loader) { described_class.new(batch_loader: batch_loader) }

  before(:each) { file_loader.load("fakefile", filehandle: fh) }

  it "deserializes items using the given batch loader" do
    expect(batch_loader.loaded.flatten.first).to be_a(FakeItem)
  end

  it "groups items in batches" do
    expect(batch_loader.loaded.map {|a| a.map(&:line) })
      .to include(["thing1", "thing1"])
  end

  it "loads all lines" do
    expect(batch_loader.loaded.flatten.count).to eq(3)
  end

  it "loads the given data" do
    expect(batch_loader.loaded.flatten.map(&:line))
      .to contain_exactly("thing1", "thing1", "thing2")
  end

  it "doesn't send an empty batch" do
    expect(batch_loader.loaded).not_to include([])
  end
end