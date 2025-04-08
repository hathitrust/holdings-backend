# frozen_string_literal: true

# frozen string_literal: true

require "spec_helper"
require "concordance_validation/delta"
require "fileutils"

# make test files

RSpec.describe ConcordanceValidation::Delta do
  let(:old_concordance) { described_class.validated_concordance_path "old_concordance.txt" }
  let(:new_concordance) { described_class.validated_concordance_path "new_concordance.txt" }
  let(:old_concordance_gz) { described_class.validated_concordance_path "old_concordance.txt.gz" }
  let(:new_concordance_gz) { described_class.validated_concordance_path "new_concordance.txt.gz" }
  let(:delta) { described_class.new("old_concordance.txt", "new_concordance.txt") }
  let(:delta_with_gzip) { described_class.new("old_concordance.txt.gz", "new_concordance.txt.gz") }
  # FIXME: create input, output, and expected file contents that are a bit more real-world.

  before(:each) do
    FileUtils.mkdir_p Settings.concordance_path + "/validated/"
    FileUtils.mkdir_p Settings.concordance_path + "/diffs/"
    File.write(old_concordance, ["dupe\tdupe", "delete\tdelete"].join("\n"))
    File.write(new_concordance, ["dupe\tdupe", "add\tadd"].join("\n"))
    `gzip -c #{old_concordance} > #{old_concordance_gz}`
    `gzip -c #{new_concordance} > #{new_concordance_gz}`
  end

  describe "#run" do
    context "with compressed concordance files" do
      it "writes a file of deletes to the diff_out_path + .deletes" do
        delta_with_gzip.run
        deletes = File.open(delta.diff_out_path + ".deletes")
        expect(deletes.readlines).to eq(["delete\tdelete\n"])
      end

      it "writes a file of adds to the diff_out_path + .adds" do
        delta_with_gzip.run
        adds = File.open(delta.diff_out_path + ".adds")
        expect(adds.readlines).to eq(["add\tadd\n"])
      end
    end

    context "with uncompressed concordance files" do
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
end
