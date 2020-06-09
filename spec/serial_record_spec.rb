# frozen_string_literal: true

require_relative "../bin/load_print_serials"

RSpec.describe "load_print_serials" do
  describe "#extract_issns" do
    let(:i_field) { "2326-4810 | 2326-4845 (online)" }

    it "splits an issn field" do
      expect(extract_issns(i_field).first).to eq("2326-4810")
      expect(extract_issns(i_field).last).to eq("2326-4845 (online)")
    end
  end

  describe "#print_serial_to_record" do
    let(:line) do
      "000011035\t(OCoLC)ocm00754262 | (OCoLC)861791462 | "\
      "(OCoLC)ocn861791462\t\tBUHR GRAD"
    end

    it "parses a tsv line" do
      expect(print_serial_to_record(line)).to eq(
        record_id: 11_035,
        ocns: [754_262, 861_791_462],
        issns: [],
        locations: "BUHR GRAD"
      )
    end
  end

  describe "#extract_ocns" do
    let(:o_field) { "(OCoLC)ocm023536349" }
    let(:o_multi_field) { "(OCoLC)ocm00754262 | (OCoLC)861791462" }
    let(:o_multi2) { "OCoLC)1755762 (OCoLC)24527036" }

    it "filters out text from an OCN" do
      expect(extract_ocns(o_field).first).to eq(23_536_349)
    end

    it "handles multiple ocns" do
      expect(extract_ocns(o_multi_field).first).to eq(754_262)
      expect(extract_ocns(o_multi_field).last).to eq(861_791_462)
    end

    it "handles multiple ocns without |" do
      expect(extract_ocns(o_multi2).first).to eq(1_755_762)
    end
  end
end
