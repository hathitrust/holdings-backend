# frozen_string_literal: true

require "spec_helper"

require_relative "../bin/holdings_deleter"

RSpec.describe HoldingsDeleter do
  def neu(*args)
    described_class.new(args)
  end

  def fake_clusters(org, count = 10)
    1.upto(count) do |ocn|
      h1 = build(:holding, ocn: ocn, organization: org)
      Clustering::ClusterHolding.new(h1).cluster.tap(&:save)
    end
  end

  def count_holdings_by_org(org)
    holdings = []
    # This could be slow if done on real data,
    # and is dumb enough that it only just works for asserting these tests.
    Cluster.collection.find.each do |c|
      c["holdings"].each do |h|
        holdings << h if h["organization"] == org
      end
    end
    holdings.count
  end

  def empty_clusters
    Cluster.collection.aggregate(
      [
        { "$match": { "holdings.0":        { "$exists": 0 } } },
        { "$match": { "commitments.0":     { "$exists": 0 } } },
        { "$match": { "ht_items.0":        { "$exists": 0 } } },
        { "$match": { "ocn_resolutions.0": { "$exists": 0 } } }
      ]
    )
  end

  describe "params" do
    it "requires params" do
      expect { neu }.to raise_exception(RuntimeError)
      expect { neu([]) }.to raise_exception(RuntimeError)
    end

    it "requires valid params" do
      expect { neu("foo", "bar") }.to raise_exception(RuntimeError)
      expect { neu("--ocn", "1") }.not_to raise_exception
      expect { neu("--organization", "yale") }.not_to raise_exception
    end

    it "date_received must be parseable as a Date" do
      expect do
        neu("--date_received", "potato").run
      end.to raise_exception(OptionParser::InvalidArgument)
      expect { neu("--date_received", "2020-01-01") }.not_to raise_exception
    end

    it "can take many params" do
      many_params = [ # ugly bc rubocop thinks it's too long otherwise
        "--ocn", "1", "--organization", "1", "--local_id", "1",
        "--enum_chron", "1", "--n_enum", "1", "--n_chron", "1",
        "--status", "CH", "--condition", "BRT", "--mono_multi_serial", "mono",
        "--country_code", "se", "--uuid", "1", "--issn", "1",
        "--date_received", "2020-01-01", "--weight", "1.33",
        "--gov_doc_flag", "true", "--noop", "1"
      ]
      expect { neu(*many_params) }.not_to raise_exception
    end

    it "does nothing if noop is set" do
      expect(neu("--organization", "uh", "--noop").run).to eq nil
    end

    it "lets you inspect its criteria" do
      crit = neu(
        "--organization", "uh",
        "--ocn", "5",
        "--date_received", "2020-01-01"
      ).matching_criteria

      expect(crit[:organization]).to eq "uh"
      expect(crit[:ocn]).to eq 5
      expect(crit[:date_received]).to eq Date.parse("2020-01-01")
    end
  end

  describe "deletes" do
    before(:each) do
      Cluster.create_indexes
      Cluster.collection.find.delete_many
    end

    it "deletes all matching holdings" do
      expect(Cluster.collection.count).to eq(0)
      fake_clusters("umich")
      expect(count_holdings_by_org("umich")).to eq(10)
      neu("--organization", "umich").run
      expect(count_holdings_by_org("umich")).to eq(0)
    end

    it "leaves non-matching holdings untouched" do
      fake_clusters("umich")
      fake_clusters("smu")
      expect(count_holdings_by_org("umich")).to eq(10)
      neu("--organization", "umich").run
      expect(count_holdings_by_org("umich")).to eq(0)
      expect(count_holdings_by_org("smu")).to eq(10)
    end

    it "we can get more specific" do
      fake_clusters("umich")
      fake_clusters("smu")
      res = neu("--organization", "umich", "--ocn", "5").run
      expect(res.documents.first["nModified"]).to eq 1
      expect(count_holdings_by_org("umich")).to eq 9
      expect(count_holdings_by_org("smu")).to eq 10
    end

    it "leaves no empty clusters by default" do
      expect(empty_clusters.count).to eq(0)
      fake_clusters("umich")
      expect(count_holdings_by_org("umich")).to eq(10)
      deleter = neu("--organization", "umich")
      deleter.run
      expect(empty_clusters.count + count_holdings_by_org("umich")).to eq(0)
    end

    it "leaves empty clusters only if told to" do
      expect(empty_clusters.count).to eq(0)
      fake_clusters("umich")
      deleter = neu("--organization", "umich", "--leave_empties")
      deleter.run
      expect(empty_clusters.count).to eq(10)
      # Call to explicitly delete.
      deleter.delete_empty_clusters
      expect(empty_clusters.count).to eq(0)
    end

    xit "placeholder for actually testing session/cursor timeout" do
      # todo
    end
  end
end
