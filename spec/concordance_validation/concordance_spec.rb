# frozen_string_literal: true

require "spec_helper"
require "concordance_validation/concordance"

RSpec.describe ConcordanceValidation::Concordance do
  describe "#numbers_tab_numbers" do
    it "raises an error if it isn't numbers-tab-numbers throughout" do
      expect do
        described_class.numbers_tab_numbers(
          "spec/concordance_validation/data/letters_tab_letters.tsv"
        )
      end.to \
        raise_error("Invalid format. 2 line(s) are malformed.")
    end

    it "does not raise an error if it is numbers-tab-numbers throughout" do
      cromulent_file = "spec/concordance_validation/data/cycles.tsv"
      expect { described_class.numbers_tab_numbers(cromulent_file) }.not_to \
        raise_error
    end
  end

  describe "terminal_ocn" do
    it "can find root ocns" do
      chained = described_class.new("spec/concordance_validation/data/chained.tsv")
      expect(chained.canonical_ocn(1)).to eq(3)
    end

    it "complains if there are multiple terminal ocns" do
      multi = described_class.new("spec/concordance_validation/data/multiple_terminal.tsv")
      expect { multi.canonical_ocn(1) }.to \
        raise_error("OCN:1 resolves to multiple ocns: 2, 3")
    end
  end

  describe "described_class.new" do
    it "builds a basic concordance structure" do
      chained_file = "spec/concordance_validation/data/chained.tsv"
      expect(described_class.new(chained_file).to_h).to \
        eq(1 => [2], 2 => [3])
    end

    it "handles gzipped files" do
      chained_gzip_file = "spec/concordance_validation/data/chained.tsv.gz"
      expect(described_class.new(chained_gzip_file).to_h).to \
        eq(1 => [2], 2 => [3])
    end
  end

  describe "compile_sub_graph" do
    it "compiles a list of all edges when given an ocn" do
      disconnected = described_class.new("spec/concordance_validation/data/disconnected.tsv")
      expect(disconnected.compile_sub_graph(2)).to eq([{1 => [2, 3], 2 => [3]},
        {2 => [1], 3 => [1, 2]}])
    end
  end

  describe "detect_cycles" do
    it "detects cycles" do
      cycles = described_class.new("spec/concordance_validation/data/cycles.tsv")
      sub = cycles.compile_sub_graph(1)
      expect { cycles.detect_cycles(*sub) }.to \
        raise_error("Cycles: 1, 2, 3")
    end

    it "detects more indirect cycles" do
      indirect_cycles = described_class.new("spec/concordance_validation/data/indirect_cycles.tsv")
      sub = indirect_cycles.compile_sub_graph(2)
      expect { indirect_cycles.detect_cycles(*sub) }.to \
        raise_error("Cycles: 2, 3")
    end

    it "detects cycles in noncontiguous graphs" do
      cycles = described_class.new("spec/concordance_validation/data/noncontiguous_cycle_graph.tsv")
      sub = cycles.compile_sub_graph(1)
      expect { cycles.detect_cycles(*sub) }.to \
        raise_error("Cycles: 2, 3, 4, 5")
    end

    it "returns a long list of ocns if no cycles found" do
      noncycles = described_class.new("spec/concordance_validation/data/not_cycle_graph.tsv")
      sub = noncycles.compile_sub_graph(2)
      expect { noncycles.detect_cycles(*sub) }.not_to \
        raise_error
    end
  end
end
