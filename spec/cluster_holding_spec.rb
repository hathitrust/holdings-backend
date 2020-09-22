# frozen_string_literal: true

require "cluster_holding"
RSpec.describe ClusterHolding do
  let(:h) { build(:holding) }
  let(:c) { create(:cluster, ocns: [h.ocn]) }

  describe "#cluster" do
    before(:each) do
      Cluster.each(&:delete)
      # @h = build(:holding)
      # @c = create(:cluster, ocns: [@h.ocn])
      c.save
    end

    it "adds a holding to an existing cluster" do
      cluster = described_class.new(h).cluster
      expect(cluster.holdings.first._parent.id).to eq(c.id)
      expect(cluster.holdings.count).to eq(1)
      expect(Cluster.count).to eq(1)
    end

    it "creates a new cluster if no match is found" do
      expect(described_class.new(build(:holding)).cluster.id).not_to eq(c.id)
      expect(Cluster.count).to eq(2)
    end
  end

  describe "#update" do
    let(:h2) { h.clone }
    let(:h3) { h.clone }

    before(:each) do
      Cluster.each(&:delete)
      c.save
      h.date_received = Date.yesterday
    end

    it "updates an existing holding" do
      old_date = h.date_received
      described_class.new(h).cluster
      cluster = Cluster.first
      expect(cluster.holdings.first.date_received).to eq(old_date)
      h2.date_received = Date.today
      described_class.new(h2).update
      cluster = Cluster.first
      expect(cluster.holdings.first.date_received).not_to eq(old_date)
      expect(cluster.holdings.first.date_received).to eq(h2.date_received)
    end

    it "updates only one existing holding" do
      described_class.new(h).cluster
      described_class.new(h.clone).cluster
      h2.date_received = Date.today
      described_class.new(h2).update
      cluster = Cluster.first
      expect(cluster.holdings.first.date_received).to eq(h2.date_received)
      expect(cluster.holdings.last.date_received).not_to \
        eq(h2.date_received)
    end

    it "does not update already updated holding" do
      described_class.new(h).cluster
      h2.date_received = Date.today
      described_class.new(h2).update
      cluster = Cluster.first
      expect(cluster.holdings.first.date_received).to eq(h2.date_received)
      h3.date_received = h2.date_received
      described_class.new(h3).update
      cluster = Cluster.first
      expect(cluster.holdings.count).to eq(2)
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
      cluster = described_class.new(h.clone).cluster
      expect(Cluster.count).to eq(1)
      holding = cluster.holdings.first
      described_class.new(holding).delete
      expect(Cluster.count).to eq(1)
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
      described_class.new(old2).cluster
      new1.date_received = current_date
      new2.date_received = current_date
      # replaces first old record
      described_class.new(new1).update
      # adds new record
      new2.status = "WD"
      described_class.new(new2).update
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
      c.save
      c = described_class.new(h.clone).cluster
      c.save
      c = described_class.new(h.clone).cluster
      c.save
      new_copy = h.clone
      new_copy.date_received = new_date
      c = described_class.new(new_copy).update
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
