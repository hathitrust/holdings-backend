require "spec_helper"
require "ex_libris_holdings_xml_parser"

RSpec.describe ExLibrisHoldingsXmlParser do
  let(:organization) { "umich" }
  let(:input_mon) { fixture("exlibris_mon_in.xml") }
  let(:input_ser) { fixture("exlibris_ser_in.xml") }
  let(:output_mon) { fixture("exlibris_mon_out.tsv") }
  let(:output_ser) { fixture("exlibris_ser_out.tsv") }
  let(:inputs) { [input_mon, input_ser] }
  let(:full_parser) {
    described_class.new(
      organization: organization,
      files: inputs,
      output_dir: ENV["TEST_TMP"]
    )
  }

  describe "#initialize" do
    it "returns an ExLibrisHoldingsXmlParser" do
      parser = described_class.new(organization: organization, files: inputs)
      expect(parser).to be_a described_class
    end
    it "requires both organization and files" do
      expect { described_class.new }.to raise_error(ArgumentError)
      expect { described_class.new(organization: organization) }.to raise_error(ArgumentError)
      expect { described_class.new(files: inputs) }.to raise_error(ArgumentError)
    end
  end

  describe "#run" do
    it "generates the expected outputs without errors" do
      full_parser.run
      expect(full_parser.record_count).to eq 10
      expect(full_parser.errors.count).to eq 0
      expect(FileUtils.compare_file(full_parser.output_files[:mon].path, output_mon)).to be_truthy
      expect(FileUtils.compare_file(full_parser.output_files[:ser].path, output_ser)).to be_truthy
    end
  end
end
