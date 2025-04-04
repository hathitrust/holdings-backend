# frozen_string_literal: true

require "spec_helper"
require "cluster"

RSpec.describe Cluster do
  let(:ocn1) { rand(1_000_000) }
  let(:ocn2) { ocn1 + 1 }
  let(:ocn3) { ocn2 + 1 }
  let(:ht) { build(:ht_item).to_hash }

  include_context "with tables for holdings"

  describe "#initialize" do
    it "creates a new cluster" do
      expect(described_class.new(ocns: [ocn1]).class).to eq(described_class)
    end

    it "has an ocns field that is Set" do
      expect(described_class.new(ocns: [ocn1]).ocns.class).to eq(Set)
    end

    it "has an ocns field with members that are Integers" do
      expect(described_class.new(ocns: [ocn1]).ocns.first.class).to eq(Integer)
    end
  end

  describe "#for_ocns" do
    it "gets a cluster with the given ocn" do
      expect(described_class.for_ocns([ocn1]).ocns).to contain_exactly(ocn1)
    end

    it "gets a cluster with multiple ocns" do
      expect(described_class.for_ocns([ocn1, ocn2]).ocns).to contain_exactly(ocn1, ocn2)
    end

    it "gets all related ocns for htitems" do
      load_test_data(build(:ht_item, ocns: [ocn1, ocn2]))

      expect(described_class.for_ocns([ocn1]).ocns).to contain_exactly(ocn1, ocn2)
    end

    it "gets all related ocns for concordance resolutions" do
      load_test_data(build(:ocn_resolution, variant: ocn1, canonical: ocn2))

      expect(described_class.for_ocns([ocn1]).ocns).to contain_exactly(ocn1, ocn2)
      expect(described_class.for_ocns([ocn2]).ocns).to contain_exactly(ocn1, ocn2)
    end

    it "gets all related ocns for variants of canonical ocns on the htitem" do
      load_test_data(build(:ht_item, ocns: [ocn1, ocn2]))
      load_test_data(build(:ocn_resolution, variant: ocn3, canonical: ocn2))

      expect(described_class.for_ocns([ocn2]).ocns).to contain_exactly(ocn1, ocn2, ocn3)
    end

    it "gets all related ocns for canonical ocns" do
      load_test_data(build(:ht_item, ocns: [ocn1, ocn2]))
      load_test_data(build(:ocn_resolution, variant: ocn2, canonical: ocn3))

      expect(described_class.for_ocns([ocn3]).ocns).to contain_exactly(ocn1, ocn2, ocn3)
    end

    it "gets all related ocns for canonical ocns (querying for ocn on htitem)" do
      load_test_data(build(:ht_item, ocns: [ocn1, ocn2]))
      load_test_data(build(:ocn_resolution, variant: ocn2, canonical: ocn3))

      expect(described_class.for_ocns([ocn1]).ocns).to contain_exactly(ocn1, ocn2, ocn3)
    end
  end

  describe "#ht_items" do
    it "finds htitems with one matching ocn" do
      htitem = build(:ht_item, ocns: [ocn1])
      insert_htitem(htitem)

      cluster_items = Cluster.new(ocns: [ocn1]).ht_items
      expect(cluster_items.to_a.length).to eq(1)
      expect(cluster_items.first.item_id).to eq(htitem.item_id)
    end

    context "with a cluster with multiple ocns" do
      it "returns ht items where some ocns match" do
        htitem = build(:ht_item, ocns: [ocn1])
        insert_htitem(htitem)

        cluster_items = Cluster.new(ocns: [ocn1, ocn2]).ht_items
        expect(cluster_items.to_a.length).to eq(1)
        expect(cluster_items.first.item_id).to eq(htitem.item_id)
      end

      it "returns multiple ht items with different ocns" do
        htitem1 = build(:ht_item, ocns: [ocn1])
        insert_htitem(htitem1)

        htitem2 = build(:ht_item, ocns: [ocn2])
        insert_htitem(htitem2)
        cluster_items = Cluster.new(ocns: [ocn1, ocn2]).ht_items
        expect(cluster_items.to_a.length).to eq(2)
        expect(cluster_items.find { |i| i.item_id == htitem1.item_id }).not_to be(nil)
        expect(cluster_items.find { |i| i.item_id == htitem2.item_id }).not_to be(nil)
      end

      it "returns ht items where all ocns match" do
        htitem = build(:ht_item, ocns: [ocn1, ocn2])
        insert_htitem(htitem)

        cluster_items = Cluster.new(ocns: [ocn1, ocn2]).ht_items
        expect(cluster_items.to_a.length).to eq(1)
        expect(cluster_items.first.item_id).to eq(htitem.item_id)
      end
    end
  end

  describe "#holdings" do
    it "can find a holding with an ocn" do
      holding = create(:holding, ocn: ocn1)
      cluster_holdings = Cluster.new(ocns: [ocn1]).holdings
      expect(cluster_holdings.to_a.length).to eq(1)
      expect(cluster_holdings.first.local_id).to eq(holding.local_id)
    end

    it "can find multiple holdings in a cluster with multiple ocns" do
      holdings = [
        create(:holding, ocn: ocn1),
        create(:holding, ocn: ocn2)
      ]
      cluster_holdings = Cluster.new(ocns: [ocn1, ocn2]).holdings
      expect(cluster_holdings.to_a.length).to eq(2)
      expect(cluster_holdings.map(&:local_id)).to contain_exactly(*holdings.map(&:local_id))
    end
  end

  describe "#format" do
    it "has a format" do
      htitem = build(:ht_item)
      insert_htitem(htitem)

      c = Cluster.new(ocns: htitem.ocns)

      formats = ["spm", "mpm", "ser"]
      expect(formats).to include(c.format)
    end
  end

  describe "Precomputed fields" do
    let(:h1) { build(:holding, ocn: ocn1, enum_chron: "1", organization: "umich") }
    let(:h2) { build(:holding, ocn: ocn1, enum_chron: "2", organization: "umich") }
    let(:ht1) { build(:ht_item, ocns: [ocn1], enum_chron: "3", collection_code: "MIU") }
    let(:cluster) { Cluster.new(ocns: [ocn1]) }

    before(:each) do
      load_test_data(h1, h2, ht1,
        build(:holding, ocn: ocn2, organization: "umich"),
        build(:holding, ocn: ocn2, organization: "umich"),
        build(:holding, ocn: ocn2, organization: "smu"))
    end

    describe "#organizations_in_cluster" do
      it "collects all of the organizations found in the cluster" do
        expect(cluster.organizations_in_cluster)
          .to contain_exactly("umich")
      end
    end

    describe "#item_enums" do
      it "collects all item enums in the cluster" do
        expect(cluster.item_enums).to contain_exactly("3")
      end
    end

    describe "#holding_enum_orgs" do
      it "maps enums to member holdings" do
        expect(cluster.holding_enum_orgs[h1.n_enum]).to contain_exactly(h1.organization)
      end
    end

    describe "#org_enums" do
      it "maps orgs to their enums" do
        expect(cluster.org_enums[h1.organization]).to contain_exactly(h1.n_enum, h2.n_enum)
      end
    end

    describe "#organizations_with_holdings_but_no_matches" do
      it "is a list of orgs in the cluster that don't match anything" do
        create(:holding, ocn: ocn1, enum_chron: "4", organization: "ualberta")
        expect(cluster.organizations_with_holdings_but_no_matches).to include("ualberta")
      end

      it "does not include orgs that do have a match" do
        matching_holding = create(:holding, ocn: ocn1, enum_chron: "3")
        expect(cluster.organizations_with_holdings_but_no_matches).not_to \
          include(matching_holding.organization)
      end

      it "DOES NOT include orgs that only have a billing entity match" do
        ht2 = build(:ht_item, ocns: [ocn1], enum_chron: "5", collection_code: "AEU")
        insert_htitem(ht2)
        expect(cluster.organizations_with_holdings_but_no_matches).not_to include("ualberta")
        # but does if they have a non-matching holding
        create(:holding, ocn: ocn1, enum_chron: "6", organization: "ualberta")
        cluster.invalidate_cache
        expect(cluster.organizations_with_holdings_but_no_matches).to include("ualberta")
      end
    end

    describe "#holdings_by_org" do
      it "collates holdings by org" do
        c = described_class.new(ocns: [ocn2])
        expect(c.holdings_by_org["umich"].size).to eq(2)
        expect(c.holdings_by_org["smu"].size).to eq(1)
      end
    end

    describe "#copy_counts" do
      it "counts holdings per org" do
        c = described_class.new(ocns: [ocn2])
        expect(c.copy_counts["umich"]).to eq(2)
        expect(c.copy_counts["smu"]).to eq(1)
      end

      xit "cached counts should be invalidated when holdings/ht_items are changed" do
        c = described_class.new(ocns: [ocn2])
        expect(c.copy_counts["umich"]).to eq(2)
        c.holdings.map(&:delete)
        expect(c.holdings.size).to eq(0)
        expect(c.copy_counts["umich"]).to eq(0)
      end
    end
  end
end
