require "workflows/deposit_holdings_analysis"

RSpec.describe Workflows::DepositHoldingsAnalysis::Analyzer do
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

      it "returns status held if depositing institution reports holding a title" do
        load_test_data(ht_item, holding_for(ht_item))

        expect(analyzer.analyze(ht_item)).to eq(:held)
      end

      it "returns status not held if depositing institution does not report holding a title" do
        load_test_data(ht_item)

        expect(analyzer.analyze(ht_item)).to eq(:not_held)
      end

      it "returns status withdrawn if depositing institution only reports holding as withdrawn" do
        holding = holding_for(ht_item, status: 'WD')
        load_test_data(ht_item, holding)

        if(analyzer.analyze(ht_item)) != :withdrawn
          puts holding.inspect
          puts ht_item.inspect
        end

        expect(analyzer.analyze(ht_item)).to eq(:withdrawn)
      end

      it "returns status held if depositing institution reports holding a withdrawn and a currently-held copy" do
        load_test_data(ht_item, 
                       holding_for(ht_item, status: 'WD'),
                       holding_for(ht_item, status: 'CH'))

        expect(analyzer.analyze(ht_item)).to eq(:held)
      end

      it "returns status lost_missing if depositing institution only reports holding a lost or missing copy" do
        load_test_data(ht_item, 
                       holding_for(ht_item, status: 'LM'))

        expect(analyzer.analyze(ht_item)).to eq(:lost_missing)
      end

      it "returns status lost_missing if the depositing institution reports holding a withdrawn and a lost/missing copy" do
        # maybe more useful to know that it's LM than that there are also
        # withdrawn copies?
        
        load_test_data(ht_item, 
                       holding_for(ht_item, status: 'LM'),
                       holding_for(ht_item, status: 'WD'))

        expect(analyzer.analyze(ht_item)).to eq(:lost_missing)
      end
    end
  end
end
