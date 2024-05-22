# frozen_string_literal: true

require "spec_helper"

require_relative "../bin/cleanup_duplicate_holdings"

RSpec.describe CleanupDuplicateHoldings do
  def set_blank_fields(holding, value)
    [:n_enum=, :n_chron=, :condition=, :issn=].each do |setter|
      holding.public_send(setter, value)
    end
  end

  def blank_fields_holding(**kwargs)
    build(:holding, :all_fields, **kwargs).tap { |h| set_blank_fields(h, "") }
  end

  def nil_fields_dupe_holding(h)
    h.clone.tap do |h2|
      set_blank_fields(h2, nil)
      h2._id = nil
      h2.uuid = SecureRandom.uuid
      h2.date_received = Date.yesterday
    end
  end

  before(:each) { Cluster.each(&:delete) }

  describe "run" do
    it "cleans up duplicate holdings" do
      holding = blank_fields_holding
      create(:cluster, holdings: [holding, nil_fields_dupe_holding(holding)])

      described_class.new.run

      expect(Cluster.first.holdings.count).to eq(1)
    end

    it "leaves non-duplicate holdings alone" do
      holding = blank_fields_holding
      another_holding = blank_fields_holding
      create(:cluster, holdings: [
        holding,
        nil_fields_dupe_holding(holding),
        another_holding
      ])

      described_class.new.run

      cluster_holdings = Cluster.first.holdings
      expect(cluster_holdings.length).to eq(2)
      expect(cluster_holdings[0]).not_to eq(cluster_holdings[1])
    end

    it "cleans up duplicate holdings from multiple organizations in a cluster" do
      umich_holding = blank_fields_holding(organization: "umich")
      upenn_holding = blank_fields_holding(organization: "upenn")
      create(:cluster, holdings: [
        umich_holding,
        upenn_holding,
        nil_fields_dupe_holding(umich_holding),
        nil_fields_dupe_holding(upenn_holding)
      ])

      described_class.new.run

      expect(Cluster.first.holdings.count).to eq(2)
      expect(Cluster.first.holdings.map(&:organization).uniq).to contain_exactly("umich", "upenn")
    end

    it "cleans up more than two duplicate holdings in a cluster" do
      holding = blank_fields_holding
      create(:cluster, holdings: [
        holding,
        nil_fields_dupe_holding(holding),
        nil_fields_dupe_holding(holding)
      ])

      described_class.new.run

      expect(Cluster.first.holdings.count).to eq(1)
    end

    it "cleans up multiple clusters with duplicate holdings" do
      holding = blank_fields_holding
      create(:cluster, holdings: [
        holding,
        nil_fields_dupe_holding(holding)
      ])

      holding2 = blank_fields_holding
      create(:cluster, holdings: [
        holding2,
        nil_fields_dupe_holding(holding2)
      ])

      described_class.new.run

      expect(Cluster.count).to eq(2)
      Cluster.each do |c|
        expect(c.holdings.count).to eq(1)
      end
    end

    it "keeps the holding with the most recent date received" do
      # By default, the factory creates the holding with today's date;
      # the duplicate holding has yesterday's date
      holding = blank_fields_holding
      create(:cluster, holdings: [holding, nil_fields_dupe_holding(holding)])

      described_class.new.run

      expect(Cluster.first.holdings[0].date_received).to eq(Date.today)
    end

    it "logs what it's working on at DEBUG level" do
      Services.register(:logger) { Logger.new($stdout, level: Logger::DEBUG) }

      create(:cluster)

      expect { described_class.new.run }.to output(/#{Cluster.first.ocns.first}/).to_stdout
    end

    it "logs how many clusters it's worked on" do
      Services.register(:logger) { Logger.new($stdout, level: Logger::INFO) }
      create(:cluster)

      expect { described_class.new.run }.to output(/Processed 1 cluster/).to_stdout
    end

    it "logs how many holdings it's worked on" do
      Services.register(:logger) { Logger.new($stdout, level: Logger::INFO) }

      holding = blank_fields_holding
      create(:cluster, holdings: [holding, nil_fields_dupe_holding(holding)])

      expect { described_class.new.run }.to output(/Processed 2 old holdings.*Kept 1 holding/m).to_stdout
    end
  end
end
