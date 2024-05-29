# frozen_string_literal: true

require "spec_helper"

require "cleanup_duplicate_holdings"

RSpec.describe CleanupDuplicateHoldings, type: :sidekiq_fake do
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

  def cluster_ids
    Cluster.all.map(&:id).map(&:to_s)
  end

  before(:each) { Cluster.each(&:delete) }

  describe "self.queue_jobs" do
    it "queues a job of the expected size for each batch of holdings" do
      10.times { create(:cluster) }

      expect { described_class.queue_jobs(job_cluster_count: 5) }
        .to change(described_class.jobs, :size).by(2)

      expect(described_class.jobs[0]["args"][0].length).to eq(5)
      expect(described_class.jobs[1]["args"][0].length).to eq(5)
    end

    it "queues jobs for all clusters" do
      10.times { create(:cluster) }

      described_class.queue_jobs(job_cluster_count: 5)

      cluster_ids = described_class.jobs.map { |job| job["args"][0] }.flatten
      expect(cluster_ids).to eq(Cluster.all.map(&:id).map(&:to_s))
    end
  end

  describe "perform" do
    it "cleans up duplicate holdings" do
      holding = blank_fields_holding
      create(:cluster, holdings: [holding, nil_fields_dupe_holding(holding)])

      described_class.new.perform(cluster_ids)

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

      described_class.new.perform(cluster_ids)

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

      described_class.new.perform(cluster_ids)

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

      described_class.new.perform(cluster_ids)

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

      described_class.new.perform(cluster_ids)

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

      described_class.new.perform(cluster_ids)

      expect(Cluster.first.holdings[0].date_received).to eq(Date.today)
    end

    it "logs what it's working on" do
      Services.register(:logger) { Logger.new($stdout, level: Logger::DEBUG) }

      create(:cluster)

      expect { described_class.new.perform(cluster_ids) }.to output(/#{Cluster.first.ocns.first}/).to_stdout
    end

    it "logs how many clusters it's worked on" do
      Services.register(:logger) { Logger.new($stdout, level: Logger::INFO) }
      create(:cluster)

      expect { described_class.new.perform(cluster_ids) }.to output(/Processed.* 1 cluster/).to_stdout
    end

    it "logs how many holdings it's worked on" do
      Services.register(:logger) { Logger.new($stdout, level: Logger::INFO) }

      holding = blank_fields_holding
      create(:cluster, holdings: [holding, nil_fields_dupe_holding(holding)])

      expect { described_class.new.perform(cluster_ids) }.to output(/Processed.* 2 old holdings.* kept 1 holding/).to_stdout
    end

    it "doesn't save the cluster when there are no duplicate holdings" do
      create(:cluster,
        holdings: [
          build(:holding),
          build(:holding)
        ])

      orig_time = Cluster.first.last_modified

      described_class.new.perform(cluster_ids)

      expect(Cluster.first.last_modified).to eq(orig_time)
    end
  end
end
