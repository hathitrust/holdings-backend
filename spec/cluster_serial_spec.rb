# frozen_string_literal: true

require "cluster_serial"

RSpec.describe ClusterSerial do
  let(:s) { build(:serial) }
  let(:c) { create(:cluster, ocns: s.ocns) }

  describe "#cluster" do
    before(:each) do
      Cluster.each(&:delete)
      c.save
    end

    it "adds a serial to an existing cluster" do
      cluster = described_class.new(s).cluster
      expect(cluster.serials.first._parent.id).to eq(c.id)
      expect(cluster.serials.to_a.size).to eq(1)
      expect(Cluster.each.to_a.size).to eq(1)
    end

    # This should never actually happen as all Serial Records are for exiting
    # HT materials
    it "does not create a new cluster if no match is found" do
      expect(described_class.new(build(:serial)).cluster).to be_nil
      expect(Cluster.each.to_a.size).to eq(1)
    end
  end

  describe "#move" do
    let(:c2) { create(:cluster) }

    before(:each) do
      Cluster.each(&:delete)
      c.save
    end

    it "moves a serial from one cluster to another" do
      cluster = described_class.new(s).cluster
      expect(cluster.serials.to_a.size).to eq(1)
      described_class.new(s).move(c2)
      expect(cluster.serials.to_a.size).to eq(0)
      expect(c2.serials.to_a.size).to eq(1)
    end
  end
end
