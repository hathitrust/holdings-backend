# frozen_string_literal: true

require "spec_helper"
require "batch_cluster_ht_item"
RSpec.describe BatchClusterHtItem do
  let(:item) { build(:ht_item) }
  let(:ocns) { item.ocns }
  let(:batch) { [item,build(:ht_item, ocns: ocns)] }
  let(:empty_cluster) { create(:cluster, ocns: ocns) }
  let(:cluster_with_item) { create(:cluster, ocns: ocns, ht_items: [item]) }
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
    empty_cluster.save
    cluster = described_class.new(ocns).cluster(batch)

    expect(cluster._id).to eq(empty_cluster._id)
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

    multiple_ocns = empty_cluster.ocns + c2.ocns

    item2 = build(:ht_item, ocns: multiple_ocns)
    item3 = build(:ht_item, ocns: multiple_ocns)

    cluster = described_class.new(multiple_ocns).cluster([item2,item3])
    cluster.save

    expect(Cluster.count).to eq(1)
    expect(Cluster.first.ocns).to contain_exactly(*multiple_ocns)
  end

  it "updates if the htitems need updating" do
    cluster_with_item.save

    update_item = build(:ht_item, item_id: item.item_id, ocns: item.ocns)

    cluster = described_class.new(update_item.ocns).cluster([update_item]).tap(&:save)

    expect(cluster.ht_items.length).to eq(1)
    expect(cluster.ht_items[0].ht_bib_key).to eq(update_item.ht_bib_key)
  end

  it "moves if the ocn needs updating" do
    cluster_with_item.save

    update_item = build(:ht_item, item_id: item.item_id, ocns: [item.ocns[0] + 1])

    cluster = described_class.new(update_item.ocns).cluster([update_item]).tap(&:save)
    expect(Cluster.for_ocns(item.ocns).count).to eq(0)

  end

  it "first looks in the cluster it has for the htitem to update" do
    # ocn hasn't changed, so htitem should be in the initial cluster we got and
    # we shouldn't have to go fish
    cluster_with_item.save
    expect(Cluster).not_to receive(:with_ht_item)

    update_item = build(:ht_item, item_id: item.item_id, ocns: item.ocns)
    cluster = described_class.new(update_item.ocns).cluster([update_item])

  end

end
