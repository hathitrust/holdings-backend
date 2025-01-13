# frozen_string_literal: true

require "spec_helper"
require "cluster"

RSpec.describe Cluster do
  let(:ocn1) { 5 }
  let(:ocn2) { 6 }
  let(:ht) { build(:ht_item).to_hash }

  describe "#initialize" do
    include_context "with cluster ocns table"

    it "creates a new cluster" do
      expect(described_class.new(ocns: [ocn1]).class).to eq(described_class)
    end

    it "has an ocns field that is Array" do
      expect(described_class.new(ocns: [ocn1]).ocns.class).to eq(Array)
    end

    it "has an ocns field with members that are Integers" do
      expect(described_class.new(ocns: [ocn1]).ocns.first.class).to eq(Integer)
    end

    it "can retrieve a cluster's ocns given its id" do
      import_cluster_ocns(
        1 => [1001, 1002, 1003]
      )

      c = Cluster.find(id: 1)
      expect(c.ocns).to contain_exactly(1001, 1002, 1003)
    end

    describe "#for_ocns" do
      it "returns Clusters" do
        import_cluster_ocns(
          1 => [1001],
          2 => [1002]
        )

        clusters = Cluster.for_ocns([1001, 1002])
        expect(clusters).to all(be_a(Cluster))
      end

      it "given one OCN, returns an existing cluster" do
        import_cluster_ocns(
          1 => [1001]
        )

        c = Cluster.for_ocns([1001]).first
        expect(c.id).to eq(1)
      end

      it "given multiple OCNs matching a single cluster, returns it" do
        import_cluster_ocns(
          1 => [1001, 1002, 1003]
        )

        c = Cluster.for_ocns([1001, 1002]).first
        expect(c.id).to eq(1)
      end

      it "given multiple OCNs matching different clusters, returns them" do
        import_cluster_ocns(
          1 => [1001],
          2 => [1002]
        )

        clusters = Cluster.for_ocns([1001, 1002])
        expect(clusters.map(&:id)).to contain_exactly(1, 2)
      end

      it "given multiple OCNs where not all OCNs match a cluster, returns the matching clusters" do
        import_cluster_ocns(
          1 => [1001],
          2 => [1002]
        )

        clusters = Cluster.for_ocns([1001, 1003])
        expect(clusters.map(&:id)).to contain_exactly(1)
      end

      it "given OCNs where no OCN matches a cluster, returns an empty array" do
        import_cluster_ocns(
          1 => [1001],
          2 => [1002]
        )

        clusters = Cluster.for_ocns([9000, 9001])
        expect(clusters.any?).to be(false)
      end
    end

    describe "#ht_items" do
      include_context "with hathifiles table"

      it "in a cluster with one ocn, returns matching htitem" do
        import_cluster_ocns(
          1 => [1001]
        )

        htitem = build(:ht_item, ocns: [1001])
        insert_htitem(htitem)

        cluster_items = Cluster.find(id: 1).ht_items
        expect(cluster_items.to_a.length).to eq(1)
        expect(cluster_items.first.item_id).to eq(htitem.item_id)
      end

      context "with a cluster with multiple ocns" do
        before(:each) { import_cluster_ocns({1 => [1001, 1002]}) }

        it "returns ht items where some ocns match" do
          htitem = build(:ht_item, ocns: [1001])
          insert_htitem(htitem)

          cluster_items = Cluster.find(id: 1).ht_items
          expect(cluster_items.to_a.length).to eq(1)
          expect(cluster_items.first.item_id).to eq(htitem.item_id)
        end

        it "returns multiple ht items with different ocns" do
          htitem1 = build(:ht_item, ocns: [1001])
          insert_htitem(htitem1)

          htitem2 = build(:ht_item, ocns: [1002])
          insert_htitem(htitem2)

          cluster_items = Cluster.find(id: 1).ht_items
          expect(cluster_items.to_a.length).to eq(2)
          expect(cluster_items.find { |i| i.item_id == htitem1.item_id }).not_to be(nil)
          expect(cluster_items.find { |i| i.item_id == htitem2.item_id }).not_to be(nil)
        end

        it "returns ht items where all ocns match" do
          htitem = build(:ht_item, ocns: [1001, 1002])
          insert_htitem(htitem)

          cluster_items = Cluster.find(id: 1).ht_items
          expect(cluster_items.to_a.length).to eq(1)
          expect(cluster_items.first.item_id).to eq(htitem.item_id)
        end
      end
    end

    xit "validates the ocns field is numeric" do
      expect(described_class.new(ocns: ["a"])).not_to be_valid
    end

    xit "validates that it has all HT Item ocns" do
      c = described_class.new(ocns: [ocn1])
      c.save
      c.ht_items.create(ht)
      c.ht_items.first.ocns << rand(1_000_000)
      c.save
      expect(c.errors.messages[:ocns]).to include("must contain all ocns")
    end

    xit "prevents duplicate HT Items" do
      c = described_class.new(ocns: [ocn1])
      c.save
      c.ht_items.create(ht)
      c2 = described_class.new(ocns: [ocn2])
      c2.save
      expect { c2.ht_items.create(ht) }.to \
        raise_error(Mongo::Error::OperationFailure, /ht_items.item_id_1 dup/)
    end
  end

  xdescribe "#format" do
    let(:c1) { create(:cluster) }

    it "has a format" do
      formats = ["spm", "mpm", "ser"]
      expect(formats).to include(c1.format)
    end
  end

  xdescribe "#last_modified" do
    let(:c1) { build(:cluster) }

    it "doesn't have last_modified if unsaved" do
      expect(c1.last_modified).to be_nil
    end

    it "has last_modified if it is saved" do
      now = Time.now.utc
      c1.save
      expect(c1.last_modified).to be > now
    end

    it "updates last_modified when it is saved" do
      c1.save
      first_timestamp = c1.last_modified
      c1.save
      second_timestamp = c1.last_modified
      expect(first_timestamp).to be < second_timestamp
    end
  end

  xdescribe "#save" do
    let(:c1) { build(:cluster, ocns: [ocn1, ocn2]) }
    let(:c2) { build(:cluster, ocns: [ocn2]) }

    it "can't save them both" do
      c1.save
      expect { c2.save }.to \
        raise_error(Mongo::Error::OperationFailure, /duplicate key error/)
    end

    it "saves to the database" do
      c1.save
      expect(described_class.count).to eq(1)
      expect(described_class.where(ocns: ocn1).count).to eq(1)
    end
  end

  xdescribe "Precomputed fields" do
    let(:h1) { build(:holding, ocn: ocn1, enum_chron: "1") }
    let(:h2) { build(:holding, ocn: ocn1, enum_chron: "2", organization: h1.organization) }
    let(:ht1) { build(:ht_item, ocns: [ocn1], enum_chron: "3", billing_entity: h1.organization) }

    before(:each) do
      Clustering::ClusterHolding.new(h1).cluster.tap(&:save)
      Clustering::ClusterHolding.new(h2).cluster.tap(&:save)
      Clustering::ClusterHtItem.new(ht1).cluster.tap(&:save)
      Clustering::ClusterHolding.new(build(:holding, ocn: ocn2, organization: "umich"))
        .cluster.tap(&:save)
      Clustering::ClusterHolding.new(build(:holding, ocn: ocn2, organization: "umich"))
        .cluster.tap(&:save)
      Clustering::ClusterHolding.new(build(:holding, ocn: ocn2, organization: "smu"))
        .cluster.tap(&:save)
    end

    describe "#organizations_in_cluster" do
      it "collects all of the organizations found in the cluster" do
        expect(described_class.first.organizations_in_cluster).to \
          eq([h1.organization, h2.organization, ht1.billing_entity].uniq)
      end
    end

    describe "#item_enums" do
      it "collects all item enums in the cluster" do
        c = described_class.first
        expect(c.item_enums).to eq(["3"])
      end
    end

    describe "#holding_enum_orgs" do
      it "maps enums to member holdings" do
        c = described_class.first
        expect(c.holding_enum_orgs[h1.n_enum]).to eq([h1.organization])
      end
    end

    describe "#org_enums" do
      it "maps orgs to their enums" do
        c = described_class.first
        expect(c.org_enums[h1.organization]).to eq([h1.n_enum, h2.n_enum])
      end
    end

    describe "#organizations_with_holdings_but_no_matches" do
      it "is a list of orgs in the cluster that don't match anything" do
        h3 = build(:holding, ocn: ocn1, enum_chron: "4", organization: "ualberta")
        Clustering::ClusterHolding.new(h3).cluster.tap(&:save)
        c = described_class.first
        expect(c.organizations_with_holdings_but_no_matches).to include("ualberta")
      end

      it "does not include orgs that do have a match" do
        matching_holding = build(:holding, ocn: ocn1, enum_chron: "3")
        Clustering::ClusterHolding.new(matching_holding).cluster.tap(&:save)
        c = described_class.first
        expect(c.organizations_with_holdings_but_no_matches).not_to \
          include(matching_holding.organization)
      end

      it "DOES NOT include orgs that only have a billing entity match" do
        ht2 = build(:ht_item, ocns: [ocn1], enum_chron: "5", billing_entity: "ualberta")
        Clustering::ClusterHtItem.new(ht2).cluster.tap(&:save)
        c = described_class.first
        expect(c.organizations_with_holdings_but_no_matches).not_to include("ualberta")
        # but does if they have a non-matching holding
        h3 = build(:holding, ocn: ocn1, enum_chron: "6", organization: "ualberta")
        Clustering::ClusterHolding.new(h3).cluster.tap(&:save)
        c = described_class.where(ocns: ocn1).first
        expect(c.organizations_with_holdings_but_no_matches).to include("ualberta")
      end
    end

    describe "#holdings_by_org" do
      it "collates holdings by org" do
        c = described_class.where(ocns: ocn2).first
        expect(c.holdings_by_org["umich"].size).to eq(2)
        expect(c.holdings_by_org["smu"].size).to eq(1)
      end
    end

    describe "#copy_counts" do
      it "counts holdings per org" do
        c = described_class.where(ocns: ocn2).first
        expect(c.copy_counts["umich"]).to eq(2)
        expect(c.copy_counts["smu"]).to eq(1)
      end

      xit "cached counts should be invalidated when holdings/ht_items are changed" do
        c = described_class.where(ocns: ocn2).first
        expect(c.copy_counts["umich"]).to eq(2)
        c.holdings.map(&:delete)
        expect(c.holdings.size).to eq(0)
        expect(c.copy_counts["umich"]).to eq(0)
      end
    end
  end
end
