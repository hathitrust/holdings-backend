require "workflows/map_reduce"
require "workflows/deposit_holdings_analysis"

RSpec.describe Workflows::DepositHoldingsAnalysis do
  describe Workflows::DepositHoldingsAnalysis::Analyzer do
    include_context "with tables for holdings"

    describe "#analyze" do
      let(:analyzer) { described_class.new("nonexistent.json") }

      def holding_for(ht_item, **kwargs)
        build(:holding,
          organization: ht_item.billing_entity,
          ocn: ht_item.ocns.first,
          **kwargs)
      end

      context "serial" do
        # serials don't have status or condition information, so we would only
        # return held or not_held

        let(:ht_item) { build(:ht_item, :ser) }

        it "returns status held if depositing institution reports holding a title" do
          load_test_data(ht_item, holding_for(ht_item))

          expect(analyzer.analyze(ht_item)).to eq(:held)
        end

        it "returns status not held if depositing institution does not report holding a title" do
          load_test_data(ht_item)

          expect(analyzer.analyze(ht_item)).to eq(:not_held)
        end
      end

      context "multi-part monograph" do
        let(:ht_item) { build(:ht_item, :mpm, enum_chron: "V.1") }

        it "returns status held if depositing institution reports holding a copy with the same enumchron" do
          load_test_data(ht_item, holding_for(ht_item, enum_chron: "V.1"))

          expect(analyzer.analyze(ht_item)).to eq(:held)
        end

        it "returns status held if depositing institution reports holding only copies with no enumchrons" do
          load_test_data(ht_item, holding_for(ht_item))

          expect(analyzer.analyze(ht_item)).to eq(:held)
        end

        it "returns status not held if depositing institution reports holding only copies with different enumchrons" do
          load_test_data(ht_item, holding_for(ht_item, enum_chron: "volume 99"))

          expect(analyzer.analyze(ht_item)).to eq(:not_held)
        end

        it "returns status not held if depositing institution does not report holding a title" do
          load_test_data(ht_item)

          expect(analyzer.analyze(ht_item)).to eq(:not_held)
        end
      end

      context "single-part monograph" do
        let(:ht_item) { build(:ht_item, :spm) }

        it "returns status no_ocn if the item doesn't have an OCLC number" do
          no_ocn_item = build(:ht_item, :spm, ocns: [])
          load_test_data(no_ocn_item)

          expect(analyzer.analyze(no_ocn_item)).to eq(:no_ocn)
        end

        it "returns status held if depositing institution reports holding a title" do
          load_test_data(ht_item, holding_for(ht_item))

          expect(analyzer.analyze(ht_item)).to eq(:held)
        end

        it "returns status not held if depositing institution does not report holding a title" do
          load_test_data(ht_item)

          expect(analyzer.analyze(ht_item)).to eq(:not_held)
        end

        it "returns status withdrawn if depositing institution only reports holding as withdrawn" do
          holding = holding_for(ht_item, status: "WD")
          load_test_data(ht_item, holding)

          expect(analyzer.analyze(ht_item)).to eq(:withdrawn)
        end

        it "returns status held if depositing institution reports holding a withdrawn and a currently-held copy" do
          load_test_data(ht_item,
            holding_for(ht_item, status: "WD"),
            holding_for(ht_item, status: "CH"))

          expect(analyzer.analyze(ht_item)).to eq(:held)
        end

        it "returns status lost_missing if depositing institution only reports holding a lost or missing copy" do
          load_test_data(ht_item,
            holding_for(ht_item, status: "LM"))

          expect(analyzer.analyze(ht_item)).to eq(:lost_missing)
        end

        it "returns status lost_missing if the depositing institution reports holding a withdrawn and a lost/missing copy" do
          # maybe more useful to know that it's LM than that there are also
          # withdrawn copies?

          load_test_data(ht_item,
            holding_for(ht_item, status: "LM"),
            holding_for(ht_item, status: "WD"))

          expect(analyzer.analyze(ht_item)).to eq(:lost_missing)
        end
      end

      describe "mapped holdings" do
        # both stanford and ualberta map to stanford_mapped
        # ht_item deposited by ualberta
        # ualberta doesn't report holding; stanford does

        let(:ht_item) { build(:ht_item, :spm, billing_entity: "ualberta") }
        let(:holding) { holding_for(ht_item, status: "CH", organization: "stanford") }

        before(:each) { load_test_data(ht_item, holding) }

        it "analyze_mapped has status held" do
          expect(analyzer.analyze_mapped(ht_item, "stanford_mapped")).to eq(:held)
        end

        it "includes both mapped & non-mapped info" do
          expect(analyzer.report_for(ht_item)).to eq(
            [ht_item.item_id, "ualberta", :not_held, "stanford_mapped", :held]
          )
        end
      end
    end
  end

  describe "integration test with Workflow::MapReduce" do
    include_context "with tables for holdings"
    include_context "with mocked solr response"

    let(:workflow) do
      components = {
        data_source: WorkflowComponent.new(
          Workflows::DepositHoldingsAnalysis::DataSource
        ),
        mapper: WorkflowComponent.new(
          Workflows::DepositHoldingsAnalysis::Analyzer
        ),
        reducer: WorkflowComponent.new(
          Workflows::DepositHoldingsAnalysis::Writer
        )
      }
      Workflows::MapReduce.new(test_mode: true, components: components)
    end

    it "includes data for held and not-held in-copyright items" do
      current_holding = build(:holding, organization: "umich", ocn: "2779601", enum_chron: "v.1")
      withdrawn_holding = build(:holding, organization: "umich", ocn: "2779601", enum_chron: "v.2", status: "WD")

      load_test_data(current_holding, withdrawn_holding)

      workflow.run

      output = Zlib::GzipReader.open(Dir.glob("#{ENV["TEST_TMP"]}/overlap_reports/deposit_holdings_analysis_*.tsv.gz").first)

      lines = output.to_a
      # header line + one record for each IC item in solr fixture
      expect(lines.count).to eq(12)
      expect(lines[0]).to eq("item_id\tbilling_entity\tholdings_status\tmapto_inst_id\tmapped_holdings_status\n")
      # ocn 2779601 v.1
      expect(lines).to include("mdp.39015066356547\tumich\theld\tumich\theld\n")
      # ocn 2779601 v.2
      expect(lines).to include("mdp.39015066356406\tumich\twithdrawn\tumich\twithdrawn\n")
      # ocn 2779601 v.5
      expect(lines).to include("mdp.39015018415946\tumich\tnot_held\tumich\tnot_held\n")
    end
  end
end
