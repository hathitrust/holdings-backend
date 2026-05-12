require "spec_helper"
require "ex_libris_holdings_xml_parser"
require "marc"

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

RSpec.describe HTRecord do
  let(:marc_record) { MARC::Record.new }
  let(:serial) { MARC::Record.new.tap { |r| r.leader[7] = "s" } }

  describe "#initialize" do
    it "returns an HTRecord" do
      expect(described_class.new(marc_record)).to be_a described_class
    end
  end

  describe "#condition" do
    ["BRITTLE", "DAMAGED", "DETERIORATING", "FRAGILE"].each do |condition|
      it "returns BRT when condition is #{condition}" do
        marc_record << MARC::DataField.new("ITM", " ", " ", ["c", condition])
        expect(described_class.new(marc_record).condition).to eq("BRT")
      end
    end

    it "returns empty string for missing ITM|c value" do
      marc_record << MARC::DataField.new("ITM", " ", " ")
      expect(described_class.new(marc_record).condition).to eq("")
    end

    it "raises if there is no ITM datafield" do
      expect {
        described_class.new(marc_record).condition
      }.to raise_error(StandardError)
    end
  end

  describe "#status" do
    context "with a serial" do
      ["LOST_ILL", "LOST_LOAN", "MISSING"].each do |status|
        it "returns `nil` for status #{status}" do
          serial << MARC::DataField.new("ITM", " ", " ", ["k", status])
          expect(described_class.new(serial).status).to eq(nil)
        end
      end

      it "returns `nil` for missing ITM|k value" do
        serial << MARC::DataField.new("ITM", " ", " ")
        expect(described_class.new(serial).status).to eq(nil)
      end
    end

    context "with a monograph" do
      ["LOST_ILL", "LOST_LOAN", "MISSING"].each do |status|
        it "returns `LM` for status #{status}" do
          marc_record << MARC::DataField.new("ITM", " ", " ", ["k", status])
          expect(described_class.new(marc_record).status).to eq("LM")
        end
      end

      # Sample attested Alma Process Status values that don't translate to lost/missing.
      ["ACQ", "CLAIM_RETURNED_LOAN", "ILL", "LOAN"].each do |status|
        it "returns `CH` for non-lost/missing status #{status}" do
          marc_record << MARC::DataField.new("ITM", " ", " ", ["k", status])
          expect(described_class.new(marc_record).status).to eq("CH")
        end
      end

      it "returns `CH` for missing ITM|k value" do
        marc_record << MARC::DataField.new("ITM", " ", " ")
        expect(described_class.new(marc_record).status).to eq("CH")
      end
    end

    it "raises if there is no ITM datafield" do
      expect {
        described_class.new(marc_record).status
      }.to raise_error(StandardError)
    end
  end
end
