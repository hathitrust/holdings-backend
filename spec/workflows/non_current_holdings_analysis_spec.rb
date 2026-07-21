require "workflows/map_reduce"
require "workflows/non_current_holdings_analysis"

RSpec.describe Workflows::NonCurrentHoldingsAnalysis do
  include_context "with tables for holdings"

  describe Workflows::NonCurrentHoldingsAnalysis::Analyzer do
    let(:analyzer) { described_class.new("nonexistent.json") }

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
      # ocns and htids are ones included in solr_response_all_rights.json

      holdings = [
        # v1: pd
        build(:holding, mono_multi_serial: "mpm", organization: "umich", ocn: "2779601", enum_chron: "v.1", status: "LM"),

        # v2: ic
        build(:holding, mono_multi_serial: "mpm", organization: "umich", ocn: "2779601", enum_chron: "v.2", status: "WD"),
        build(:holding, mono_multi_serial: "mpm", organization: "upenn", ocn: "2779601", enum_chron: "v.2", condition: "BRT", status: "CH"),

        # v3: ic
        build(:holding, mono_multi_serial: "mpm", organization: "umich", ocn: "2779601", enum_chron: "v.3", condition: "BRT", status: "CH"),
        build(:holding, mono_multi_serial: "mpm", organization: "umich", ocn: "2779601", enum_chron: "v.3", status: "LM"),

        # v4: icus, should be counted as PD for US org
        build(:holding, mono_multi_serial: "mpm", organization: "upenn", ocn: "2779601", enum_chron: "v.4", condition: "BRT", status: "CH"),

        # v5: pdus, should be counted as PD for non-US org
        build(:holding, mono_multi_serial: "mpm", organization: "ualberta", ocn: "2779601", enum_chron: "v.5", status: "LM"),

        # pdus
        build(:holding, mono_multi_serial: "spm", organization: "upenn", ocn: "23536349", status: "WD")
      ]

      load_test_data(*holdings)

      workflow.run

      output = File.open(Dir.glob("#{ENV["TEST_TMP"]}/overlap_reports/non_current_holdings_analysis_*.tsv").first)

      lines = output.to_a
      # one record for each organization with non-current holdings
      expect(lines.count).to eq(4)

      expect(lines[0]).to eq("organization\tpd: withdrawn\tpd: lost/missing\tpd: brittle\tpd: multiple\tic: withdrawn\tic: lost/missing\tic: brittle\tic: multiple\n")
      # ualberta: one pd lost+misssing
      expect(lines).to include("ualberta\t0\t1\t0\t0\t0\t0\t0\t0\n")
      # umich: one pd lost+missing, one ic withdrawn, one ic multiple
      expect(lines).to include("umich\t0\t1\t0\t0\t1\t0\t0\t1\n")
      # upenn: one pd withdrawn, one pd brittle, one ic brittle
      expect(lines).to include("upenn\t1\t0\t1\t0\t0\t0\t1\t0\n")
    end
  end
end
