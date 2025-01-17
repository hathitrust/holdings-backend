# frozen_string_literal: true

require "spec_helper"
require "clustering/cluster_ht_item"
RSpec.describe Clustering::ClusterHtItem do
  let(:item) { build(:ht_item, ocns: ocns) }
  let(:item2) { build(:ht_item, ocns: ocns) }
  let(:ocn) { rand(1..1_000_000) }
  let(:ocns) { [ocn] }
  let(:batch) { [item, item2] }
  let(:empty_cluster) { build(:cluster, ocns: ocns) }
  let(:cluster_with_item) { create(:cluster, ocns: ocns, ht_items: [item]) }
  let(:no_ocn) { build(:ht_item, ocns: []) }

  include_context "with cluster ocns table"
  include_context "with hathifiles table"

  describe "#initialize" do
    it "accepts a single HTItem" do
      expect(described_class.new(item)).not_to be nil
    end

    it "accepts multiple HTItems as an array" do
      expect(described_class.new(batch)).not_to be nil
    end

    it "accepts multiple HTItems as direct arguments" do
      expect(described_class.new(item, item2)).not_to be nil
    end

    it "raises ArgumentError with two HTItems with different single OCNs" do
      expect do
        described_class.new([item, build(:ht_item)])
      end.to raise_exception(ArgumentError)
    end

    it "raises ArgumentError with two HTItems with different multiple OCNs" do
      expect do
        described_class.new([
          build(:ht_item, ocns: [1, 2]),
          build(:ht_item, ocns: [1, 3])
        ])
      end.to raise_exception(ArgumentError)
    end

    it "raises ArgumentError with two HTItems without an OCN" do
      expect do
        described_class.new([
          build(:ht_item, ocns: []),
          build(:ht_item, ocns: [])
        ])
      end.to raise_exception(ArgumentError)
    end
  end

  describe "#cluster" do
    it "adds multiple htitems to the cluster" do
      # these will already be in the hf table
      batch.each { |htitem| insert_htitem(htitem) }

      cluster = described_class.new(batch).cluster
      expect(cluster.ht_items.to_a.size).to eq(2)
    end

    xit "first looks in the cluster it has for the htitem to update" do
      # ocn hasn't changed, so htitem should be in the initial cluster we got and
      # we shouldn't have to go fish
      cluster_with_item.save
      expect(Cluster).not_to receive(:with_ht_item)

      update_item = build(:ht_item, item_id: item.item_id, ocns: item.ocns)
      described_class.new(update_item).cluster
    end

    it "adds an HT Item to an existing cluster" do
      # this will already be in the hf table
      insert_htitem(item)

      empty_cluster.save
      cluster = described_class.new(item).cluster
      expect(cluster.ht_items.first.cluster.id).to eq(empty_cluster.id)
      expect(cluster.ht_items.to_a.size).to eq(1)
      expect(Cluster.count).to eq(1)
    end

    xit "updates the last_modified_date when adding an htitem" do
      empty_cluster.save
      orig_last_modified = empty_cluster.last_modified
      cluster = described_class.new(item).cluster

      expect(cluster.last_modified).to be > orig_last_modified
    end

    it "creates a new cluster if no match is found" do
      new_item = build(:ht_item)
      # this will already be in the hf table
      insert_htitem(new_item)

      empty_cluster.save
      new_cluster = described_class.new(new_item).cluster
      expect(new_cluster.id).not_to eq(empty_cluster.id)
      expect(Cluster.count).to eq(2)
    end

    xit "merges two or more clusters" do
      # first cluster with ht's ocns
      c = described_class.new(item).cluster
      # a second cluster with different ocns
      new_item = build(:ht_item)
      second_c = described_class.new(new_item).cluster
      # ht with ocns overlapping both
      overlapping_item = build(:ht_item, ocns: c.ocns + second_c.ocns)
      cluster = described_class.new(overlapping_item).cluster
      expect(Cluster.count).to eq(1)
      expect(cluster.ht_items.to_a.size).to eq(3)
    end

    it "new OCN on item is added to cluster" do
      # cluster with one OCN
      empty_cluster.save

      # add an item with that OCN and a second OCN
      item.ocns << ocn + 1
      insert_htitem(item)
      cluster = described_class.new(item).cluster

      # cluster should have all item OCNs
      expect(cluster.ocns.to_a).to eq(item.ocns.to_a)
    end

    xit "creates a new cluster for an OCNless Item" do
      cluster = described_class.new(no_ocn).cluster
      expect(cluster.ht_items.to_a.first.item_id).to eq(no_ocn.item_id)
    end

    xit "cluster without OCN contains OCNless Item" do
      cluster = described_class.new(no_ocn).cluster
      expect(cluster.ht_items.to_a.first).to eq(no_ocn)
      expect(Cluster.each.to_a.first.ht_items.to_a.first).to eq(no_ocn)
    end

    xit "creates a new cluster for multiple OCNless Items" do
      no_ocn2 = build(:ht_item, ocns: [])
      cluster = described_class.new(no_ocn).cluster
      cluster2 = described_class.new(no_ocn2).cluster
      expect(cluster).not_to eq(cluster2)
      expect(Cluster.count).to eq(2)
    end

    xcontext "with HT2 as an update to HT" do
      let(:update_item) { build(:ht_item, item_id: item.item_id) }

      it "removes the old cluster" do
        first = described_class.new(item).cluster
        described_class.new(update_item).cluster
        expect(Cluster.count).to eq(1)
        new_cluster = Cluster.each.to_a.first
        expect(new_cluster).not_to eq(first)
        expect(new_cluster.ht_items.first).to eq(update_item)
      end
    end

    xcontext "with HT2 with the same OCNS as HT" do
      let(:update_item) { build(:ht_item, item_id: item.item_id, ocns: item.ocns) }

      it "only updates the HT Item" do
        first = described_class.new(item).cluster
        updated = described_class.new(update_item).cluster
        expect(first).to eq(updated)
        expect(
          Cluster.each.to_a.first.ht_items.first.to_hash
        ).to eq(update_item.to_hash)
      end

      it "changes update_date when a relevant attribute changes" do
        first = described_class.new(item).cluster
        first_last_modified = first.last_modified

        updated = described_class.new(update_item).cluster

        expect(updated.last_modified).to be > first_last_modified
      end

      it "does not change cluster update when no attributes change" do
        described_class.new(item).cluster
        first_last_modified = Cluster.first.last_modified
        updated = described_class.new(item).cluster
        expect(updated.last_modified).to eq(first_last_modified)
      end
    end

    xcontext "without concordance rules" do
      it "reclusters when an HTItem in the cluster loses an OCN" do
        item2.ocns << 1
        described_class.new(item).cluster
        described_class.new(item2).cluster
        expect(Cluster.count).to eq(1)
        # remove the glue from item2
        item2.ocns = [1]
        described_class.new(item2).cluster
        expect(Cluster.count).to eq(2)
      end
    end

    xcontext "with concordance rules" do
      it "can add an HTItem" do
        resolution = build(:ocn_resolution)
        htitem = build(:ht_item, ocns: [resolution.deprecated])
        create(:cluster, ocns: resolution.ocns, ocn_resolutions: [resolution])
        c = described_class.new(htitem).cluster
        expect(c.valid?).to be true
      end

      # No longer necessary. Reclusterer will determine if it actually needs to be reclustered.
      it "reclusters if an HTItem loses an OCN that is not in a concordance rule" do
        resolution = build(:ocn_resolution, deprecated: 1, resolved: 2)
        htitem = build(:ht_item, ocns: [2, 3])
        old_cluster = create(:cluster, ocns: [1, 2, 3],
          ocn_resolutions: [resolution],
          ht_items: [htitem])

        htitem.ocns = [2]

        described_class.new(htitem).cluster
        new_cluster = Cluster.with_ht_item(htitem).first

        expect(Cluster.count).to eq(1)
        expect(new_cluster._id).not_to eq(old_cluster._id)
      end

      it "updates cluster.ocns if an HTItem loses an OCN that is not in a concordance rule" do
        resolution = build(:ocn_resolution, deprecated: 1, resolved: 2)
        htitem = build(:ht_item, ocns: [2, 3])
        create(:cluster, ocns: [1, 2, 3],
          ocn_resolutions: [resolution],
          ht_items: [htitem])

        htitem.ocns = [2]

        described_class.new(htitem).cluster
        updated_cluster = Cluster.with_ht_item(htitem).first

        expect(Cluster.count).to eq(1)
        expect(updated_cluster.ocns).to eq([1, 2])
      end

      it "does not recluster if an HTItem loses an OCN that is in the concordance" do
        resolution = build(:ocn_resolution, deprecated: 1, resolved: 2)
        htitem = build(:ht_item, ocns: [1, 2])
        old_cluster = create(:cluster, ocns: [1, 2],
          ocn_resolutions: [resolution],
          ht_items: [htitem])

        htitem.ocns = [2]

        described_class.new(htitem).cluster
        new_cluster = Cluster.with_ht_item(htitem).first

        expect(Cluster.count).to eq(1)
        expect(new_cluster._id).to eq(old_cluster._id)
      end

      it "does not recluster if an HTItem changes from one OCN to another in the concordance" do
        resolution = build(:ocn_resolution, deprecated: 1, resolved: 2)
        htitem = build(:ht_item, ocns: [1])
        old_cluster = create(:cluster, ocns: [1, 2],
          ocn_resolutions: [resolution],
          ht_items: [htitem])

        htitem.ocns = [2]

        described_class.new(htitem).cluster
        new_cluster = Cluster.with_ht_item(htitem).first

        expect(Cluster.count).to eq(1)
        expect(new_cluster._id).to eq(old_cluster._id)
      end

      it "does not recluster if the HTItem had only one OCN" do
        htitem = build(:ht_item, ocns: [3])

        old_cluster = create(:cluster, ocns: [1, 2, 3],
          ocn_resolutions: [build(:ocn_resolution, deprecated: 1, resolved: 2)],
          ht_items: [htitem,
            build(:ht_item, ocns: [1, 3])])

        htitem.ocns = [1]

        described_class.new(htitem).cluster
        new_cluster = Cluster.with_ht_item(htitem).first

        expect(Cluster.count).to eq(1)
        expect(new_cluster._id).to eq(old_cluster._id)
      end
    end

    xcontext "when HTItem is moving clusters" do
      it "deletes the old cluster for an OCN-less HTItem that gains an OCN" do
        ocnless_cluster = described_class.new(no_ocn).cluster
        ocnless_cluster.save
        empty_cluster.save
        expect(Cluster.count).to eq(2)
        updated_item = build(:ht_item, item_id: no_ocn.item_id, ocns: empty_cluster.ocns)
        described_class.new(updated_item).cluster
        expect(Cluster.count).to eq(1)
      end

      it "reclusters the old cluster if the old HTItem has multiple OCNs not in the concordance" do
        htitem = build(:ht_item, ocns: [1, 2])
        old_cluster = create(:cluster, ocns: [1, 2],
          ht_items: [htitem, build(:ht_item, ocns: [1]), build(:ht_item, ocns: [2])])

        htitem.ocns = [3]
        described_class.new(htitem).cluster

        expect(Cluster.count).to eq(3)
        reclustered = Cluster.for_ocns([1]).first
        expect(reclustered._id).not_to eq(old_cluster._id)
        expect(reclustered.ocns).to contain_exactly(1)
      end

      it "does not recluster the old cluster if the old HTItem has only one OCN" do
        htitem = build(:ht_item, ocns: [1])
        another_htitem = build(:ht_item, ocns: [1])

        old_cluster = create(:cluster, ocns: [1],
          ht_items: [htitem, another_htitem])

        htitem.ocns = [2]
        described_class.new(htitem).cluster

        same_old_cluster = Cluster.with_ht_item(another_htitem).first
        expect(Cluster.count).to eq(2)
        expect(same_old_cluster._id).to eq(old_cluster._id)
      end

      it "deletes the old cluster if it becomes empty when an HTItem changes OCN" do
        htitem = build(:ht_item, ocns: [1])

        old_cluster = create(:cluster, ocns: [1], ht_items: [htitem])

        htitem.ocns = [2]

        described_class.new(htitem).cluster
        new_cluster = Cluster.with_ht_item(htitem).first

        expect(Cluster.count).to eq(1)
        expect(new_cluster._id).not_to eq(old_cluster._id)
      end

      it "does not recluster if all the old HTItems's OCNs are covered by concordance rules" do
        htitem = build(:ht_item, ocns: [1, 2])
        old_cluster = create(:cluster, ocns: [1, 2],
          ocn_resolutions: [build(:ocn_resolution, deprecated: 1, resolved: 2)],
          ht_items: [htitem, build(:ht_item, ocns: [1])])

        htitem.ocns = [3]

        described_class.new(htitem).cluster
        same_old_cluster = Cluster.for_ocns([1]).first

        expect(Cluster.count).to eq(2)
        expect(same_old_cluster._id).to eq(old_cluster._id)
      end
    end
  end

  xdescribe "#delete" do
    let(:item2) { build(:ht_item, ocns: item.ocns) }

    before(:each) do
      Cluster.each(&:delete)
      empty_cluster.save
    end

    it "removes the cluster if it's only that htitem" do
      described_class.new(item).cluster
      expect(Cluster.count).to eq(1)
      described_class.new(item).delete
      expect(Cluster.count).to eq(0)
    end

    it "won't delete multiple items" do
      expect { described_class.new(batch).delete }.to raise_exception(ArgumentError)
    end
  end
end
