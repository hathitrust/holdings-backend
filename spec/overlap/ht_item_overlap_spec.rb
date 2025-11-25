# frozen_string_literal: true

require "spec_helper"
require "overlap/ht_item_overlap"

RSpec.describe Overlap::HtItemOverlap do
  include_context "with tables for holdings"

  let(:c) { build(:cluster) }

  let(:spm) do
    build(
      :ht_item,
      :spm,
      ocns: c.ocns,
      collection_code: "PU"
      # collection_code PU translates to billing_entity=upenn,
      # as long as Clusterable::HtItem.set_billing_entity uses
      # collection_code to determine billing_entity.
    )
  end
  let(:spm_holding1) do
    build(
      :holding,
      mono_multi_serial: "spm",
      ocn: c.ocns.first,
      organization: "umich"
    )
  end
  let(:spm_holding2) do
    build(
      :holding,
      mono_multi_serial: "spm",
      ocn: c.ocns.first,
      organization: "smu"
    )
  end
  let(:spm_holding3) do
    build(
      :holding,
      mono_multi_serial: "spm",
      ocn: c.ocns.first,
      organization: "stanford"
    )
  end

  # we end up inserting the same kinds of things...
  # this adds the given item and holdings to cluster c

  context "with an ocn-less spm" do
    describe "#organizations_with_holdings" do
      it "only returns the contributor" do
        ocnless_spm = build(:ht_item, :spm, ocns: [], collection_code: "PU")
        load_test_data(ocnless_spm)

        overlap = described_class.new(ocnless_spm)
        expect(overlap.organizations_with_holdings).to eq(["upenn"])
      end
    end
  end

  context "with an ocn-less mpm" do
    describe "#organizations_with_holdings" do
      it "only returns the contributor" do
        ocnless_mpm = build(:ht_item, :mpm, ocns: [], collection_code: "PU")
        load_test_data(ocnless_mpm)

        overlap = described_class.new(ocnless_mpm)
        expect(overlap.organizations_with_holdings).to eq(["upenn"])
      end
    end
  end

  context "with an spm cluster and spm holdings" do
    describe "#organizations_with_holdings" do
      before(:each) do
        load_test_data(spm, spm_holding1, spm_holding2, spm_holding3)
      end

      it "returns all organizations that overlap with an item" do
        overlap = described_class.new(c.ht_items.first)
        # billing_entity: upenn, holdings: smu, umich, non_matching: stanford
        expect(overlap.organizations_with_holdings.count).to eq(4)
      end

      it "only returns unique organizations" do
        # i.e. if we add another holding for an org that already holds,
        # organizations_with_holdings.count should stay the same
        overlap = described_class.new(c.ht_items.first)
        expect(c.holdings.count).to eq(3)
        expect(overlap.organizations_with_holdings.count).to eq(4)
        # add 1 more holding to a member that already holds
        create(
          :holding,
          mono_multi_serial: "spm",
          ocn: c.ocns.first,
          organization: "smu"
        )
        c.invalidate_cache
        # Number of holdings goes up, overlap.organizations_with_holdings.count does not
        expect(c.holdings.count).to eq(4)
        overlap = described_class.new(c.ht_items.first)
        expect(overlap.organizations_with_holdings.count).to eq(4)
      end
    end

    describe "members_with_holdings" do
      # Add a fake non-member with a holding,
      # and see that it is included in overlap.organizations_with_holdings,
      # but excluded from overlap.members_with_holdings.
      let(:non_member_holding) do
        Services.ht_organizations.add_temp(
          DataSources::HTOrganization.new(
            inst_id: "non_member",
            country_code: "xx",
            weight: 1.0,
            status: false
          )
        )
        build(
          :holding,
          ocn: c.ocns.first,
          organization: "non_member"
        )
      end

      it "excludes organizations that are not members" do
        load_test_data(
          spm,
          spm_holding1, spm_holding2, spm_holding3, non_member_holding
        )

        overlap = described_class.new(c.ht_items.first)
        # billing_entity: ualberta, holdings: smu, umich, excluded: non_member, non_matching: stanford
        expect(overlap.organizations_with_holdings.count).to eq(5)
        expect(overlap.members_with_holdings.count).to eq(4)
      end
    end
  end

  context "with an mpm cluster and mpm holdings" do
    let(:mpm) do
      build(:ht_item, :mpm,
        ocns: c.ocns,
        enum_chron: "1",
        n_enum: "1",
        collection_code: "PU")
    end
    let(:mpm_holding1) do
      build(:holding,
        ocn: c.ocns.first,
        organization: "umich",
        enum_chron: "1",
        n_enum: "1")
    end
    let(:mpm_holding2) do
      build(:holding,
        ocn: c.ocns.first,
        organization: "smu",
        enum_chron: "1",
        n_enum: "1")
    end
    let(:mpm_non_match_holding) do
      build(:holding,
        ocn: c.ocns.first,
        organization: "stanford",
        enum_chron: "2",
        n_enum: "2")
    end

    describe "#organizations_with_holdings" do
      before(:each) do
        load_test_data(mpm, mpm_holding1, mpm_holding2, mpm_non_match_holding)
      end

      it "returns all organizations that overlap with an item" do
        overlap = described_class.new(c.ht_items.first)
        # billing_entity: upenn, holdings: smu, umich, non_matching: stanford
        expect(overlap.organizations_with_holdings.count).to eq(4)
      end

      it "member should match mpm if none of their holdings match" do
        overlap = described_class.new(c.ht_items.first)
        expect(overlap.organizations_with_holdings).to include("stanford")
      end

      it "does not include non-matching organizations that match something else" do
        mpm2 = build(:ht_item, :mpm,
          ocns: c.ocns,
          enum_chron: "2",
          n_enum: "2",
          collection_code: "PU")
        load_test_data(mpm2)
        overlap = described_class.new(mpm2)
        expect(overlap.ht_item.n_enum).to eq("2")
        expect(overlap.organizations_with_holdings).not_to include("umich")
      end

      it "only returns unique organizations" do
        holding = build(
          :holding,
          ocn: c.ocns.first,
          organization: "umich",
          enum_chron: "1",
          n_enum: "1"
        )

        load_test_data(holding)
        expect(CalculateFormat.new(c).cluster_format).to eq("mpm")
        overlap = described_class.new(c.ht_items.first)
        expect(overlap.organizations_with_holdings.count).to eq(4)
      end

      it "matches if holding enum is ''" do
        empty_holding = build(:holding,
          ocn: c.ocns.first,
          organization: "umich",
          enum_chron: "",
          n_enum: "")

        load_test_data(empty_holding)
        overlap = described_class.new(c.ht_items.first)
        expect(overlap.organizations_with_holdings).to include("umich")
      end

      it "matches if holding enum is '', but chron exists" do
        almost_empty_holding = build(:holding,
          ocn: c.ocns.first,
          organization: "umich",
          enum_chron: "Aug",
          n_enum: "",
          n_chron: "Aug")
        load_test_data(almost_empty_holding)
        overlap = described_class.new(c.ht_items.first)
        expect(overlap.organizations_with_holdings).to include("umich")
      end

      it "does not match if ht item enum is ''" do
        empty_mpm = build(:ht_item, :mpm,
          ocns: c.ocns,
          collection_code: "PU",
          enum_chron: "",
          n_enum: "")
        load_test_data(empty_mpm)
        overlap = described_class.new(empty_mpm)
        expect(overlap.organizations_with_holdings).to eq([mpm_non_match_holding.organization,
          empty_mpm.billing_entity])
      end
    end

    describe "#h_share" do
      it "returns 0 for a member that is not a holder" do
        load_test_data(spm)
        overlap = described_class.new(c.ht_items.first)
        expect(overlap.h_share("umich")).to eq(0)
      end

      it "returns 1 for a member who is the only holder" do
        load_test_data(spm)
        overlap = described_class.new(c.ht_items.first)
        expect(overlap.h_share("upenn")).to eq(1)
      end

      it "returns ratio of organizations" do
        # that is, if there are 4 holders, each holder gets a 1/4 share.
        load_test_data(spm, spm_holding1, spm_holding2, spm_holding3)
        overlap = described_class.new(c.ht_items.first)
        expect(overlap.h_share(spm.billing_entity)).to eq(1.0 / 4)
        expect(overlap.h_share(spm_holding1.organization)).to eq(1.0 / 4)
        expect(overlap.h_share(spm_holding2.organization)).to eq(1.0 / 4)
        expect(overlap.h_share(spm_holding3.organization)).to eq(1.0 / 4)
      end

      describe "#h_share: special rules for hathitrust, keio & ucm" do
        let(:keio_item) do
          build(
            :ht_item,
            :mpm,
            ocns: c.ocns,
            collection_code: "KEIO",
            enum_chron: "1"
          )
        end

        let(:ucm_item) do
          Services.ht_organizations.add_temp(
            DataSources::HTOrganization.new(
              inst_id: "ucm",
              country_code: "es",
              weight: 1.0,
              status: true
            )
          )
          build(
            :ht_item,
            :mpm,
            ocns: c.ocns,
            collection_code: "UCM",
            enum_chron: "1"
          )
        end
        it "assigns an h_share to hathitrust for KEIO items" do
          load_test_data(keio_item)
          overlap = described_class.new(keio_item)
          expect(keio_item.billing_entity).to eq("hathitrust")
          expect(overlap.h_share("hathitrust")).to eq(1.0)
        end

        it "assigns an h_share to UCM as it would anyone else" do
          load_test_data(ucm_item)
          overlap = described_class.new(ucm_item)
          expect(ucm_item.billing_entity).to eq("ucm")
          expect(overlap.h_share("ucm")).to eq(1.0)
        end
      end
    end
  end
end
