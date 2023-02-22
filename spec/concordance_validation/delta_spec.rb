# frozen_string_literal: true

# frozen string_literal: true

require "spec_helper"
require "concordance_validation/delta"
require "fileutils"

# make test files

RSpec.describe ConcordanceValidation::Delta do
  let(:delta) { described_class.new("old_concordance.txt", "new_concordance.txt") }

  before(:each) do
    FileUtils.mkdir_p Settings.concordance_path + "/validated/"
    FileUtils.mkdir_p Settings.concordance_path + "/diffs/"
    File.write(Settings.concordance_path + "/validated/old_concordance.txt",
      ["dupe\tdupe", "delete\tdelete"].join("\n"))
    File.write(Settings.concordance_path + "/validated/new_concordance.txt",
      ["dupe\tdupe", "add\tadd"].join("\n"))
  end

  describe "#initialize" do
    it "opens the old and new concordances for reading" do
      expect(delta.old_conc.to_a.size).to eq(2)
      expect(delta.new_conc.to_a.size).to eq(2)
    end
  end

  describe "#run" do
    it "builds an index of adds" do
      delta.run
      expect(delta.adds["add"]).to include("add")
    end

    it "builds an index of deletes" do
      delta.run
      expect(delta.deletes["delete"]).to include("delete")
    end

    it "writes a file of deletes to the diff_out_path + .deletes" do
      delta.run
      deletes = File.open(delta.diff_out_path + ".deletes")
      expect(deletes.readlines).to eq(["delete\tdelete\n"])
    end

    it "writes a file of adds to the diff_out_path + .adds" do
      delta.run
      adds = File.open(delta.diff_out_path + ".adds")
      expect(adds.readlines).to eq(["add\tadd\n"])
    end
  end
end
