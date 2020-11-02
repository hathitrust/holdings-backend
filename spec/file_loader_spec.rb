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
    @loaded  = []
    @deleted = []
  end

  def item_from_line(line)
    FakeItem.new(line)
  end

  def load(batch)
    loaded << batch
  end

  def delete(item)
    deleted << item
  end

  attr_reader :loaded, :deleted
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

  describe "#load" do
    before(:each) { file_loader.load("fakefile", filehandle: fh) }

    it "deserializes items using the given batch loader" do
      expect(batch_loader.loaded.flatten.first).to be_a(FakeItem)
    end

    it "groups items in batches" do
      expect(batch_loader.loaded.map { |a| a.map(&:line) })
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

  describe "#load_deletes" do
    before(:each) { file_loader.load_deletes("fakefile", filehandle: fh) }

    it "deserializes items using the given batch loader" do
      expect(batch_loader.deleted.first).to be_a(FakeItem)
    end

    it "deletes all lines one at a time" do
      expect(batch_loader.deleted.map(&:line))
          .to contain_exactly("thing1", "thing1", "thing2")
    end
  end

  describe "Skipping the first line" do
    before(:each) do
      @handle = StringIO.new(<<~DATA)
        thing1
        thing1
        thing2
      DATA
      @bl = FakeBatchLoader.new
      @fl = FileLoader.new(batch_loader: @bl)
    end

    it "skips the first line on matching regexp" do
      @fl.load("fakefile", filehandle: @handle, skip_header_match: /thing1/)
      expect(@bl.loaded.flatten.map(&:line)).to contain_exactly("thing1", "thing2")
    end

    it "doesn't skip a line on nil skip_header_match" do
      @fl.load("fakefile", filehandle: @handle)
      expect(@bl.loaded.flatten.map(&:line)).to contain_exactly("thing1", "thing1", "thing2")
    end

    it "doesn't skip a line on failed skip_header_match" do
      @fl.load("fakefile", filehandle: @handle, skip_header_match: /junk/)
      expect(@bl.loaded.flatten.map(&:line)).to contain_exactly("thing1", "thing1", "thing2")
    end

    it "skips a line on an 'anything' match" do
      @fl.load("fakefile", filehandle: @handle, skip_header_match: /./)
      expect(@bl.loaded.flatten.map(&:line)).to contain_exactly("thing1", "thing2")
    end
  end
end
