# frozen_string_literal: true

# frozen string_literal: true

require "spec_helper"
require "concordance_validation/delta"
require "fileutils"

# make test files

RSpec.describe ConcordanceValidation::Delta do
  def validated_concordance_path(concordance)
    File.join(Settings.concordance_path, "validated", concordance)
  end

  let(:old_concordance) { validated_concordance_path "old_concordance.txt" }
  let(:new_concordance) { validated_concordance_path "new_concordance.txt" }
  let(:old_concordance_gz) { validated_concordance_path "old_concordance.txt.gz" }
  let(:new_concordance_gz) { validated_concordance_path "new_concordance.txt.gz" }
  let(:delta) { described_class.new(old_concordance, new_concordance) }
  let(:delta_with_gzip) { described_class.new(old_concordance_gz, new_concordance_gz) }
  let(:adds) { delta.diff_out_path + ".adds" }
  let(:deletes) { delta.diff_out_path + ".deletes" }
  let(:old_concordance_data) {
    <<~END
      333\t444
      777\t888
      555\t666
      111\t222
    END
  }
  let(:new_concordance_data) {
    <<~END
      999\t000
      555\t666
      333\t444
      777\t888
    END
  }
  let(:added_data) { "999\t000\n" }
  let(:deleted_data) { "111\t222\n" }

  before(:each) do
    FileUtils.mkdir_p Settings.concordance_path + "/validated/"
    FileUtils.mkdir_p Settings.concordance_path + "/diffs/"
    File.write(old_concordance, old_concordance_data)
    File.write(new_concordance, new_concordance_data)
    `gzip -c #{old_concordance} > #{old_concordance_gz}`
    `gzip -c #{new_concordance} > #{new_concordance_gz}`
  end

  describe "#run" do
    context "with compressed concordance files" do
      it "writes a file of deletes to the diff_out_path + .deletes" do
        delta_with_gzip.run
        expect(File.read(deletes)).to eq(deleted_data)
      end

      it "writes a file of adds to the diff_out_path + .adds" do
        delta_with_gzip.run
        expect(File.read(adds)).to eq(added_data)
      end
    end

    context "with uncompressed concordance files" do
      it "writes a file of deletes to the diff_out_path + .deletes" do
        delta.run
        expect(File.read(deletes)).to eq(deleted_data)
      end

      it "writes a file of adds to the diff_out_path + .adds" do
        delta.run
        expect(File.read(adds)).to eq(added_data)
      end
    end
  end
end
