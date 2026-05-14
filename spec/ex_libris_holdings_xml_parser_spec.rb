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

    it "prints errors" do
      bogus_mon = File.join(ENV["TEST_TMP"], "bogus_mon.xml")
      bogus_xml = <<~XML
        <collection>
          <record></record>
          <record></record>
          <record>
            <leader>02443cas a2200589 a 4500</leader>
          </record>
        </collection>
      XML
      File.write(bogus_mon, bogus_xml, mode: "w+")
      parser = described_class.new(
        organization: organization,
        files: [bogus_mon, input_ser],
        output_dir: ENV["TEST_TMP"]
      )
      expect {
        parser.run
      }.to output(
        match(/unexpected item type/)
        .and(match(/missing 035a/))
      ).to_stderr
    end
  end
end

RSpec.describe HTRecord do
  let(:marc_record) { MARC::Record.new } # Generic "mix"
  let(:monograph) { MARC::Record.new.tap { |r| r.leader[7] = "m" } }
  let(:serial) { MARC::Record.new.tap { |r| r.leader[7] = "s" } }
  let(:us_govdoc_008) { "850423s1951    miua         f000 0 eng d" }
  let(:us_non_govdoc_008) { "850423s1951    miua          000 0 eng d" }
  let(:non_us_govdoc_008) { "850423s1951    enka         f000 0 eng d" }

  describe "#initialize" do
    it "returns an HTRecord" do
      expect(described_class.new(marc_record)).to be_a described_class
    end
  end

  # See TODO note -- may not be used
  describe "#to_tsv" do
    it "serializes a generic record to TSV" do
      monograph << MARC::ControlField.new("008", us_non_govdoc_008)
      monograph << MARC::DataField.new("035", " ", " ", ["a", "OCLC"])
      monograph << MARC::DataField.new(
        "ITM",
        " ",
        " ",
        ["a", "volume"],
        ["b", "issue"],
        ["c", "BRITTLE"],
        ["d", "LOCAL_ID"],
        ["k", "MISSING"],
        ["i", "year"],
        ["j", "month"]
      )
      expect(described_class.new(monograph).to_tsv).to eq("mon\tOCLC\tLOCAL_ID\tLM\tBRT\tvolume,issue,year,month\t\t0")
    end
  end

  describe "#to_mon_tsv" do
    it "serializes a serial record to TSV" do
      monograph << MARC::ControlField.new("008", us_non_govdoc_008)
      monograph << MARC::DataField.new("035", " ", " ", ["a", "OCLC"])
      monograph << MARC::DataField.new(
        "ITM",
        " ",
        " ",
        ["a", "volume"],
        ["b", "issue"],
        ["c", "BRITTLE"],
        ["d", "LOCAL_ID"],
        ["k", "MISSING"],
        ["i", "year"],
        ["j", "month"]
      )
      expect(described_class.new(monograph).to_mon_tsv).to eq("OCLC\tLOCAL_ID\tLM\tBRT\tvolume,issue,year,month\t0")
    end
  end

  describe "#to_ser_tsv" do
    it "serializes a serial record to TSV" do
      serial << MARC::ControlField.new("001", "LOCAL_ID")
      serial << MARC::ControlField.new("008", us_non_govdoc_008)
      serial << MARC::DataField.new("022", " ", " ", ["a", "ISSN"])
      serial << MARC::DataField.new("035", " ", " ", ["a", "OCLC"])
      expect(described_class.new(serial).to_ser_tsv).to eq("OCLC\tLOCAL_ID\tISSN\t0")
    end
  end

  describe "#itm" do
    it "returns ITM" do
      marc_record << MARC::DataField.new("ITM", " ", " ", ["d", "ITM|d"])
      expect(described_class.new(marc_record).itm("d")).to eq("ITM|d")
    end

    it "raises if there is no ITM datafield" do
      expect {
        described_class.new(marc_record).itm("d")
      }.to raise_error(StandardError)
    end
  end

  describe "#leader" do
    it "returns MARC leader of 24 characters" do
      expect(described_class.new(serial).leader.length).to eq(24)
    end
  end

  describe "#oclc" do
    it "returns OCLC from 035|a" do
      marc_record << MARC::DataField.new("035", " ", " ", ["a", "(OCoLC)03754656"])
      expect(described_class.new(marc_record).oclc).to eq("(OCoLC)03754656")
    end

    it "raises if there is no 035|a" do
      expect {
        described_class.new(marc_record).oclc
      }.to raise_error(StandardError)
    end
  end

  describe "#local_id" do
    context "with a serial" do
      it "takes its value from the 001" do
        serial << MARC::ControlField.new("001", "001")
        serial << MARC::DataField.new("ITM", " ", " ", ["d", "ITM|d"])
        expect(described_class.new(serial).local_id).to eq("001")
      end
    end

    context "with a non-serial" do
      it "takes its value from ITM|d" do
        marc_record << MARC::ControlField.new("001", "001")
        marc_record << MARC::DataField.new("ITM", " ", " ", ["d", "ITM|d"])
        expect(described_class.new(marc_record).local_id).to eq("ITM|d")
      end
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

  describe "#item_type" do
    it "identifies a monograph as `mon`" do
      expect(described_class.new(monograph).item_type).to eq("mon")
    end

    it "identifies a serial as `ser`" do
      expect(described_class.new(serial).item_type).to eq("ser")
    end

    it "identifies non-mon non-ser item as `mix`" do
      expect(described_class.new(marc_record).item_type).to eq("mix")
    end
  end

  describe "#enum_chron" do
    it "returns ITM|a+b+i+j" do
      marc_record << MARC::DataField.new(
        "ITM",
        " ",
        " ",
        ["a", " 100 "],
        ["i", "1990"],
        ["j", "May"]
      )
      expect(described_class.new(marc_record).enum_chron).to eq("100,1990,May")
    end
  end

  describe "#issn" do
    context "with a monograph" do
      it "returns `nil`" do
        expect(described_class.new(monograph).issn).to eq(nil)
      end
    end

    context "with a serial" do
      it "returns empty array if no 022|a given" do
        expect(described_class.new(serial).issn).to eq([])
      end

      it "returns value from 022|a" do
        # 022|y is incorrect ISSN, not extracted
        serial << MARC::DataField.new("022", " ", " ", ["a", "0046-225X"], ["y", "0046-2254"])
        expect(described_class.new(serial).issn).to eq("0046-225X")
      end
    end
  end

  describe "#status" do
    context "with a serial" do
      ["LOST_ILL", "LOST_LOAN", "MISSING"].each do |status|
        it "returns empty string for status #{status}" do
          serial << MARC::DataField.new("ITM", " ", " ", ["k", status])
          expect(described_class.new(serial).status).to eq("")
        end
      end

      it "returns empty string for missing ITM|k value" do
        serial << MARC::DataField.new("ITM", " ", " ")
        expect(described_class.new(serial).status).to eq("")
      end
    end

    context "with a monograph" do
      ["LOST_ILL", "LOST_LOAN", "MISSING"].each do |status|
        it "returns `LM` for status #{status}" do
          monograph << MARC::DataField.new("ITM", " ", " ", ["k", status])
          expect(described_class.new(monograph).status).to eq("LM")
        end
      end

      # Sample attested Alma Process Status values that don't translate to lost/missing.
      ["ACQ", "CLAIM_RETURNED_LOAN", "ILL", "LOAN"].each do |status|
        it "returns `CH` for non-lost/missing status #{status}" do
          monograph << MARC::DataField.new("ITM", " ", " ", ["k", status])
          expect(described_class.new(monograph).status).to eq("CH")
        end
      end

      it "returns `CH` for missing ITM|k value" do
        monograph << MARC::DataField.new("ITM", " ", " ")
        expect(described_class.new(monograph).status).to eq("CH")
      end
    end

    it "raises if there is no ITM datafield" do
      expect {
        described_class.new(marc_record).status
      }.to raise_error(StandardError)
    end
  end

  # Just a wrapper around #is_us_govdoc? returning "0" or "1"
  # Could be combined with the `#is_us_govdoc?` tests
  describe "#govdoc" do
    it "returns 1 for US fed doc" do
      marc_record << MARC::ControlField.new("008", us_govdoc_008)
      expect(described_class.new(marc_record).govdoc).to eq("1")
    end

    it "returns 0 for US non-fed doc" do
      marc_record << MARC::ControlField.new("008", us_non_govdoc_008)
      expect(described_class.new(marc_record).govdoc).to eq("0")
    end

    it "returns 0 for non-US fed doc" do
      marc_record << MARC::ControlField.new("008", non_us_govdoc_008)
      expect(described_class.new(marc_record).govdoc).to eq("0")
    end

    it "raises if record lacks 008" do
      expect {
        described_class.new(marc_record).govdoc
      }.to raise_error(StandardError)
    end
  end

  describe "#is_us_govdoc?" do
    it "accepts US fed doc" do
      marc_record << MARC::ControlField.new("008", us_govdoc_008)
      expect(described_class.new(marc_record).is_us_govdoc?).to eq(true)
    end

    it "rejects US non-fed doc" do
      marc_record << MARC::ControlField.new("008", us_non_govdoc_008)
      expect(described_class.new(marc_record).is_us_govdoc?).to eq(false)
    end

    it "rejects non-US fed doc" do
      marc_record << MARC::ControlField.new("008", non_us_govdoc_008)
      expect(described_class.new(marc_record).is_us_govdoc?).to eq(false)
    end

    it "raises if record lacks 008" do
      expect {
        described_class.new(marc_record).is_us_govdoc?
      }.to raise_error(StandardError)
    end
  end

  describe "#is_us?" do
    it "accepts US codes" do
      ["miu", "xxu", "pr#", "us#"].each do |code|
        expect(described_class.new(marc_record).is_us?(code)).to eq(true)
      end
    end

    it "rejects non-US codes" do
      ["enk", "quc", "xx#"].each do |code|
        expect(described_class.new(marc_record).is_us?(code)).to eq(false)
      end
    end
  end
end
