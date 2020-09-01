# frozen_string_literal: true

require "spec_helper"
require "batch_cluster_ht_item"
RSpec.describe BatchClusterHtItem do
  let(:item1) { build(:ht_item) }
  let(:ocns) { item1.ocns }
  let(:batch) { [item1,build(:ht_item, ocns: ocns)] }
  let(:c) { create(:cluster, ocns: ocns) }
  let(:no_ocn) { build(:ht_item, ocns: []) }

  before(:each) do
    Cluster.each(&:delete)
  end

  it "adds all the htitems to the cluster" do
    cluster = described_class.new(ocns).cluster(batch)

    expect(cluster.ht_items.to_a.size).to eq(2)
  end

  it "creates a cluster if one doesn't exist" do
    new_item = build(:ht_item)

    expect do
      described_class.new(new_item.ocns).cluster([new_item]).save
    end.to change { Cluster.count }.by(1)
  end

  it "fetches the existing cluster if one exists" do
    c.save
    cluster = described_class.new(ocns).cluster(batch)

    expect(cluster._id).to eq(c._id)
  end

  it "handles htitems with no ocns" do
    cluster = nil

    expect do
      cluster = described_class.new([]).cluster([no_ocn])
      cluster.save
    end.to change { Cluster.count }.by(1)

    expect(cluster.ht_items.first.item_id).to eq(no_ocn.item_id)
  end

  it "merges with multiple clusters" do
    c2 = create(:cluster)

    multiple_ocns = c.ocns + c2.ocns

    item2 = build(:ht_item, ocns: multiple_ocns)
    item3 = build(:ht_item, ocns: multiple_ocns)

    cluster = described_class.new(multiple_ocns).cluster([item2,item3])
    cluster.save

    expect(Cluster.count).to eq(1)
    expect(Cluster.first.ocns).to eq(multiple_ocns)
  end

  it "updates if the htitems need updating"
  it "first looks in the cluster it has for the htitem to update"

end
