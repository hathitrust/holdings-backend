require "workflows/map_reduce"
require "workflows/non_current_holdings_analysis"

RSpec.describe Workflows::NonCurrentHoldingsAnalysis do
  describe Workflows::NonCurrentHoldingsAnalysis::Analyzer do
    include_context "with tables for holdings"
    let(:analyzer) { described_class.new("nonexistent.json") }

    def holding_for(ht_item, **kwargs)
      build(:holding,
        ocn: ht_item.ocns.first,
        **kwargs)
    end

    describe "#analyze" do
      let(:ht_item) { build(:ht_item, :spm, collection_code: "MIU") }

      it "can analyze an spm where one org holds a withdrawn item" do
        load_test_data(
          ht_item,
          holding_for(ht_item, organization: "umich", status: "WD")
        )

        expect(analyzer.analyze(ht_item).to_h).to eq({"umich" => :withdrawn})
      end

      it "can analyze an spm where one org holds a withdrawn item and one has a current holding" do
        load_test_data(
          ht_item,
          holding_for(ht_item, organization: "umich", status: "WD"),
          holding_for(ht_item, organization: "upenn", status: "CH")
        )

        expect(analyzer.analyze(ht_item).to_h).to eq({"umich" => :withdrawn})
      end

      it "returns an empty hash for an org with a withdrawn item and a current holding" do
        load_test_data(
          ht_item,
          holding_for(ht_item, organization: "umich", status: "WD"),
          holding_for(ht_item, organization: "umich", status: "CH")
        )

        expect(analyzer.analyze(ht_item).to_h).to eq({})
      end

      it "returns 'brittle' for an org with a brittle item" do
        load_test_data(
          ht_item,
          holding_for(ht_item, organization: "umich", condition: "BRT")
        )

        expect(analyzer.analyze(ht_item).to_h).to eq({"umich" => :brittle})
      end

      it "returns empty for an org with a brittle item and a current item" do
        load_test_data(
          ht_item,
          holding_for(ht_item, organization: "umich", condition: "BRT"),
          holding_for(ht_item, organization: "umich", status: "CH")
        )

        expect(analyzer.analyze(ht_item).to_h).to eq({})
      end

      it "returns 'multiple' for an org with a withdrawn and a brittle item" do
        load_test_data(
          ht_item,
          holding_for(ht_item, organization: "umich", condition: "BRT"),
          holding_for(ht_item, organization: "umich", status: "WD")
        )

        expect(analyzer.analyze(ht_item).to_h).to eq({"umich" => :multiple})
      end

      it "returns 'multiple' for an org with a withdrawn, lost/missing, and brittle items" do
        load_test_data(
          ht_item,
          holding_for(ht_item, organization: "umich", condition: "BRT"),
          holding_for(ht_item, organization: "umich", status: "WD"),
          holding_for(ht_item, organization: "umich", status: "LM")
        )

        expect(analyzer.analyze(ht_item).to_h).to eq({"umich" => :multiple})
      end

      it "returns empty for an org with current, withdrawn, lost/missing, and brittle items" do
        load_test_data(
          ht_item,
          holding_for(ht_item, organization: "umich", condition: "BRT"),
          holding_for(ht_item, organization: "umich", status: "CH"),
          holding_for(ht_item, organization: "umich", status: "WD"),
          holding_for(ht_item, organization: "umich", status: "LM")
        )

        expect(analyzer.analyze(ht_item).to_h).to eq({})
      end

      it "returns 'lost_missing' for an org with a lost/missing item" do
        load_test_data(
          ht_item,
          holding_for(ht_item, organization: "umich", status: "LM")
        )

        expect(analyzer.analyze(ht_item).to_h).to eq({"umich" => :lost_missing})
      end

      it "returns different conditions for multiple organizations with non-current holdings" do
        load_test_data(
          ht_item,
          holding_for(ht_item, organization: "umich", status: "CH"),
          holding_for(ht_item, organization: "upenn", status: "WD"),
          holding_for(ht_item, organization: "smu", status: "LM")
        )

        expect(analyzer.analyze(ht_item).to_h).to eq({
          "upenn" => :withdrawn,
          "smu" => :lost_missing
        })
      end
    end

    describe "#report_for" do
      it "includes the item id, rights, and non-current holdings summary" do
        ht_item = build(:ht_item, :spm, collection_code: "MIU", rights: "pd", item_id: "test.testitem")

        load_test_data(
          holding_for(ht_item, organization: "umich", status: "LM")
        )

        expect(analyzer.report_for(ht_item)).to eq({
          item_id: "test.testitem",
          rights: "pd",
          non_current_holdings: {"umich" => :lost_missing}
        })
      end
    end
  end

  describe "integration test with Workflow::MapReduce" do
    include_context "with tables for holdings"
    include_context "with mocked solr response"

    before(:each) do
      # we're querying solr for *everything*
      mock_solr_search_filtered(File.open(fixture("solr_response_all_rights.json")), /deleted:false/)
    end

    let(:workflow) do
      components = {
        data_source: WorkflowComponent.new(
          Workflows::NonCurrentHoldingsAnalysis::DataSource
        ),
        mapper: WorkflowComponent.new(
          Workflows::NonCurrentHoldingsAnalysis::Analyzer
        ),
        reducer: WorkflowComponent.new(
          Workflows::NonCurrentHoldingsAnalysis::Writer
        )
      }
      Workflows::MapReduce.new(test_mode: true, components: components)
    end

    it "includes counts for all items by organization with only non-current/non-brittle holdings" do
      # ocns and htids are ones included in solr_response.json

      holdings = [
        # v1: pd
        build(:holding, mono_multi_serial: "mpm", organization: "umich", ocn: "2779601", enum_chron: "v.1", status: "LM"),

        # v2: ic
        build(:holding, mono_multi_serial: "mpm", organization: "umich", ocn: "2779601", enum_chron: "v.2", status: "WD"),
        build(:holding, mono_multi_serial: "mpm", organization: "upenn", ocn: "2779601", enum_chron: "v.2", condition: "BRT", status: "CH"),

        # v3: ic
        build(:holding, mono_multi_serial: "mpm", organization: "umich", ocn: "2779601", enum_chron: "v.3", condition: "BRT", status: "CH"),
        build(:holding, mono_multi_serial: "mpm", organization: "umich", ocn: "2779601", enum_chron: "v.3", status: "LM"),

        # pdus
        build(:holding, mono_multi_serial: "mpm", organization: "upenn", ocn: "23536349", status: "WD")
      ]

      load_test_data(*holdings)

      workflow.run

      output = File.open(Dir.glob("#{ENV["TEST_TMP"]}/overlap_reports/non_current_holdings_analysis_*.tsv").first)

      lines = output.to_a
      # one record for each organization with non-current holdings
      expect(lines.count).to eq(3)

      expect(lines[0]).to eq("organization\tpd: withdrawn\tpd: lost/missing\tpd: brittle\tpd: multiple\tic: withdrawn\tic: lost/missing\tic: brittle:\tic: multiple\n")
      # umich: one pd lost+missing, one ic withdrawn, one ic multiple
      expect(lines).to include("umich\t0\t1\t0\t0\t1\t0\t0\t1\n")
      # upenn: one pd withdrawn, one ic brittle
      expect(lines).to include("upenn\t1\t0\t0\t0\t0\t0\t1\t0\n")
    end
  end
end
