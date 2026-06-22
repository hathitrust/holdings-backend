# frozen_string_literal: true

require "utils/holdings_preflight"
require "spec_helper"

RSpec.describe Utils::HoldingsPreflight do
  describe "#format_counts" do
    it "returns per-format counts and a total for an organization" do
      rows = [
        {mono_multi_serial: "ser", count: 500},
        {mono_multi_serial: "spm", count: 1000}
      ]
      allow(Clusterable::Holding).to receive(:format_counts).with("umich").and_return(rows)

      result = described_class.new.format_counts("umich")

      expect(result[:counts]).to eq([{format: "ser", count: 500}, {format: "spm", count: 1000}])
      expect(result[:total]).to eq(1500)
    end

    it "returns an empty counts array and zero total when the organization has no holdings" do
      allow(Clusterable::Holding).to receive(:format_counts).with("empty").and_return([])

      result = described_class.new.format_counts("empty")

      expect(result[:counts]).to eq([])
      expect(result[:total]).to eq(0)
    end
  end

  describe "#dir_counts" do
    let(:ft) { instance_double(Utils::FileTransfer) }
    subject(:preflight) { described_class.new(file_transfer: ft) }

    it "counts lines in each tsv file, skipping non-tsv files and directories" do
      files = [
        {"Name" => "umich_mon_2025.tsv", "Path" => "umich_mon_2025.tsv", "IsDir" => false},
        {"Name" => "umich_ser_2025.tsv", "Path" => "umich_ser_2025.tsv", "IsDir" => false},
        {"Name" => "umich_mon_2025.log", "Path" => "umich_mon_2025.log", "IsDir" => false},
        {"Name" => "archive", "Path" => "archive", "IsDir" => true}
      ]
      allow(ft).to receive(:lsjson).with("dropbox:some/dir").and_return(files)
      allow(ft).to receive(:cat).with("dropbox:some/dir/umich_mon_2025.tsv").and_yield(StringIO.new("a\nb\nc\n"))
      allow(ft).to receive(:cat).with("dropbox:some/dir/umich_ser_2025.tsv").and_yield(StringIO.new("x\ny\n"))

      result = preflight.dir_counts("dropbox:some/dir")

      expect(result[:counts]).to eq([
        {name: "umich_mon_2025.tsv", count: 3},
        {name: "umich_ser_2025.tsv", count: 2}
      ])
      expect(result[:total]).to eq(5)
    end

    it "returns empty counts and zero total when no tsv files are present" do
      files = [{"Name" => "umich_mon_2025.log", "Path" => "umich_mon_2025.log", "IsDir" => false}]
      allow(ft).to receive(:lsjson).with("dropbox:some/dir").and_return(files)

      result = preflight.dir_counts("dropbox:some/dir")

      expect(result[:counts]).to eq([])
      expect(result[:total]).to eq(0)
    end
  end
end
