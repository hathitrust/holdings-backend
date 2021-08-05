# frozen_string_literal: true

require "spec_helper"
require "clustering/cluster_holding"

RSpec.describe Clustering::ClusterHolding do
  let(:h) { build(:holding) }
  let(:batch) { [h, build(:holding, ocn: h.ocn)] }
  let(:c) { create(:cluster, ocns: [h.ocn]) }

  def new_submission(holding, date: Date.today)
    holding.dup.tap do |new_holding|
      new_holding.date_received = date
      new_holding.uuid = SecureRandom.uuid
    end
  end

  describe "#cluster" do
    before(:each) do
      Cluster.each(&:delete)
      c.save
    end

    context "when adding a new holding" do
      it "adds a holding to an existing cluster" do
        cluster = described_class.new(h).cluster
        expect(cluster.holdings.first._parent.id).to eq(c.id)
        expect(cluster.holdings.count).to eq(1)
        expect(Cluster.count).to eq(1)
      end

      it "updates cluster last modified date" do
        orig_last_modified = c.last_modified
        cluster = described_class.new(h).cluster
        expect(cluster.last_modified).to be > orig_last_modified
      end

      it "creates a new cluster if no match is found" do
        expect(described_class.new(build(:holding)).cluster.id).not_to eq(c.id)
        expect(Cluster.count).to eq(2)
      end

      it "can add a batch of holdings" do
        described_class.new(batch).cluster

        expect(Cluster.count).to eq(1)
        expect(Cluster.first.holdings.count).to eq(2)
      end
    end

    context "when updating an existing holding" do
      let(:h) { build(:holding, date_received: Date.yesterday) }
      let(:batch) { [h, build(:holding, ocn: h.ocn, date_received: Date.yesterday)] }
      let(:batch2) { batch.map {|h| new_submission(h) } }
      let(:h2) { new_submission(h) }

      it "updates an existing holding" do
        old_date = h.date_received
        described_class.new(h).cluster
        cluster = Cluster.first
        expect(cluster.holdings.first.date_received).to eq(old_date)
        described_class.new(h2).cluster
        cluster = Cluster.first
        expect(cluster.holdings.first.date_received).not_to eq(old_date)
        expect(cluster.holdings.first.date_received).to eq(h2.date_received)
      end

      it "updates only one existing holding" do
        described_class.new(h).cluster
        Cluster.first.add_holdings(h.clone)
        described_class.new(h2).cluster
        cluster = Cluster.first
        expect(cluster.holdings.first.date_received).to eq(h2.date_received)
        expect(cluster.holdings.last.date_received).not_to \
          eq(h2.date_received)
      end

      it "does not update cluster last modified date" do
        cluster = described_class.new(h).cluster
        orig_last_modified = cluster.last_modified
        updated = described_class.new(h2).cluster
        expect(updated.last_modified).to eq orig_last_modified
      end

      it "adds multiple holdings with same date but different uuids" do
        described_class.new(h).cluster
        h2.date_received = h.date_received
        described_class.new(h2).cluster
        cluster = Cluster.first
        expect(cluster.holdings.count).to eq(2)
      end

      it "can update a batch of holdings" do
        described_class.new(batch).cluster

        described_class.new(batch2).cluster
        cluster = Cluster.first
        expect(cluster.holdings.count).to eq(2)
        expect(cluster.holdings.all? {|h| h.date_received == Date.today }).to be true
      end

      it "does not add additional holdings when re-running a batch" do
        described_class.new(batch).cluster

        described_class.new(batch.map(&:dup)).cluster

        cluster = Cluster.first
        expect(cluster.holdings.count).to eq(2)
      end

      it "raises an error with different date but same uuid" do
        described_class.new(batch).cluster

        h2.uuid = h.uuid
        expect { described_class.new(h2).cluster }.to raise_exception(/same UUID/)
      end

      it "raises an error with different attributes but same uuid" do
        described_class.new(batch).cluster

        h2 = build(:holding, ocn: h.ocn, uuid: h.uuid)
        expect { described_class.new(h2).cluster }.to raise_exception(/same UUID/)
      end
    end

    context 'with a "large cluster"' do
      it 'skips duplicative holdings for a member in "large clusters"' do
        c.ocns = [Services.large_clusters.ocns.first]
        c.save
        dupes = [build(:holding, organization: "umich", ocn: c.ocns.first),
                 build(:holding, organization: "umich", ocn: c.ocns.first)]
        described_class.new(dupes).cluster
        cluster = Cluster.first
        expect(cluster.holdings.count).to eq(1)
      end

      it 'updates the date_received for "large clusters"' do
        c.ocns = [Services.large_clusters.ocns.first]
        c.save
        old = build(:holding, organization: "umich", ocn: c.ocns.first,
           date_received: Date.yesterday)
        described_class.new(old).cluster
        dupes = [build(:holding, organization: "umich", ocn: c.ocns.first,
                       date_received: Date.today),
                 build(:holding, organization: "umich", ocn: c.ocns.first,
                       date_received: Date.today)]
        described_class.new(dupes).cluster
        cluster = Cluster.first
        expect(cluster.holdings.count).to eq(1)
        expect(cluster.holdings.first.date_received).to eq(Date.today)
      end

      it "updates multiple existing holdings if cluster.large?" do
        c.ocns << Services.large_clusters.ocns.first
        c.save
        described_class.new(h).cluster
        described_class.new(h.clone).cluster
        h2 = h.dup
        h2.date_received = Date.today
        h2.uuid = SecureRandom.uuid
        described_class.new(h2).cluster
        cluster = Cluster.first
        expect(cluster.holdings.first.date_received).to eq(h2.date_received)
        expect(cluster.holdings.last.date_received).to \
          eq(h2.date_received)
      end
    end
  end

  describe "#delete" do
    before(:each) do
      Cluster.each(&:delete)
    end

    it "deletes the parent cluster if it has nothing else" do
      cluster = described_class.new(h).cluster
      expect(Cluster.count).to eq(1)
      holding = cluster.holdings.first
      described_class.new(holding).delete
      expect(Cluster.count).to eq(0)
    end

    it "does not delete the parent cluster if it has something else" do
      described_class.new(h).cluster
      cluster = Cluster.first
      cluster.add_holdings(h.clone)
      expect(Cluster.count).to eq(1)
      holding = cluster.holdings.first
      described_class.new(holding).delete
      expect(Cluster.count).to eq(1)
    end

    it "updates cluster last modified date" do
      described_class.new(h).cluster
      cluster = Cluster.first
      orig_last_modified = cluster.last_modified
      cluster.add_holdings(h.clone)
      holding = cluster.holdings.first
      described_class.new(holding).delete

      expect(Cluster.first.last_modified).to be > orig_last_modified
    end
  end

  describe "#delete_old_holdings" do
    let(:past_date) { DateTime.parse("2019-10-24") }
    let(:current_date) { DateTime.parse("2020-03-25") }
    let(:old1) do
      build(:holding,
            status: "CH",
            date_received: past_date)
    end
    let(:old2) { old1.clone }
    let(:new1) { old1.clone }
    let(:new2) { old1.clone }
    let(:c) { described_class.new(old1).cluster }

    before(:each) do
      Cluster.each(&:delete)
    end

    it "deletes old when cluster has new and updated " do
      c.save
      c.add_holdings(old2)
      new1.date_received = current_date
      new1.uuid = SecureRandom.uuid
      new2.date_received = current_date
      new2.uuid = SecureRandom.uuid
      # replaces first old record
      described_class.new(new1).cluster
      # adds new record
      new2.status = "WD"
      described_class.new(new2).cluster
      c.save
      expect(Cluster.first.holdings.size).to eq(3)
      described_class.delete_old_holdings(old1.organization, new2.date_received)
      clust = Cluster.first
      expect(clust.holdings.size).to eq(2)
      expect(clust.holdings.pluck(:date_received)).to \
        eq([current_date, current_date])
    end

    it "deletes all old records from a cluster" do
      old_date = DateTime.parse("2019-10-24")
      new_date = DateTime.parse("2020-03-25")
      h = build(:holding, date_received: old_date)
      c = described_class.new(h).cluster
      c.add_holdings(h.clone)
      c.add_holdings(h.clone)
      c.save
      new_copy = h.clone
      new_copy.date_received = new_date
      new_copy.uuid = SecureRandom.uuid
      c = described_class.new(new_copy).cluster
      c.save
      clust = Cluster.first
      expect(clust.holdings.pluck(:date_received)).to \
        eq([new_date, old_date, old_date])
      described_class.delete_old_holdings(h.organization,
                                          new_copy.date_received)
      clust = Cluster.first
      expect(clust.holdings.pluck(:date_received)).to \
        eq([new_date])
    end
  end
end
