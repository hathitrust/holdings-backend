require "spec_helper"
require "reports/shared_print_newly_ingested"
require "pathname"

RSpec.xdescribe Reports::SharedPrintNewlyIngested do
  let(:org1) { "umich" }
  let(:org2) { "smu" }
  let(:ocn1) { 1 }
  let(:ocn2) { 2 }
  let(:ocn3) { 3 }
  let(:dat1) { "2020-01-01" } # smallest date in ht_item_ids_file
  let(:dat2) { "2021-01-01" } # mid
  let(:dat3) { "2022-01-01" } # biggest date in ht_item_ids_file
  let(:datZ) { "2023-01-01" } # bigger than any date in ht_item_ids_file
  let(:itm1) { "test.foo20200101" }
  let(:itm2) { "test.foo20210101" }
  let(:itm3) { "test.foo20220101" }
  let(:bk) { "BK" }

  # Start date param values
  let(:valid_start_date) { "2020-01-01" }
  let(:invalid_start_date_lo) { "1999-01-01" }
  let(:invalid_start_date_hi) { "#{Time.now.year + 10}-12-30" }
  # ht_item_ids_file fixture contains pairs of ht_item_ids and dates.
  let(:ht_item_ids_file) { fixture("shared_print_newly_ingested_ht_items.tsv") }
  let(:invalid_ht_item_ids_file) { "/tmp/invalid_ht_item_ids_file.txt" }
  # Use this instance for most tests.
  let(:rpt) {
    described_class.new(ht_item_ids_file: ht_item_ids_file, start_date: valid_start_date)
  }
  let(:outf) { rpt.outf }

  before(:each) do
    FileUtils.rm_f(outf)
    Cluster.collection.find.delete_many
  end

  # Shorthand
  def build_item(id, ocn, org, ec = "")
    build(
      :ht_item,
      item_id: id,
      ocns: [ocn],
      bib_fmt: bk,
      billing_entity: org,
      enum_chron: ec,
      access: "allow"
    )
  end

  describe "#initialize" do
    it "is ok with no params and uses defaults" do
      expect { described_class.new }.not_to raise_error
      # Check that defaults are set
      expect(described_class.new.start_date).to eq "2022-10-01"
      expect(described_class.new.ht_item_ids_file).to eq nil
    end
    it "accepts valid start dates" do
      expect { described_class.new(start_date: valid_start_date) }.not_to raise_error
    end
    it "rejects invalid start dates" do
      expect {
        described_class.new(start_date: invalid_start_date_lo)
      }.to raise_error(/not a valid year/)
      expect {
        described_class.new(start_date: invalid_start_date_hi)
      }.to raise_error(/not a valid year/)
    end
    it "accepts valid ht_item_ids_file" do
      expect { described_class.new(ht_item_ids_file: ht_item_ids_file) }.not_to raise_error
    end
    it "rejects invalid ht_item_ids_file" do
      expect {
        described_class.new(ht_item_ids_file: invalid_ht_item_ids_file)
      }.to raise_error(/does not exist/)
    end
  end
  describe "#outf" do
    it "gives a valid path" do
      expect(File.exist?(outf)).to be false
      expect { FileUtils.touch(outf) }.not_to raise_error
    end
  end
  describe "#outf" do
    it "gives the expected string" do
      expect_header = "contributor\tht_id\trights_status\tingest_date\tholding_orgs"
      expect(rpt.header).to eq expect_header
    end
  end
  describe "#matching_ht_items" do
    it "returns nothing when the db has no items" do
      expect(rpt.matching_ht_items.to_a).to eq []
    end
    it "returns all records that match criteria" do
      cluster_tap_save(
        build_item(itm1, ocn1, org1),
        build_item(itm2, ocn2, org1),
        build_item(itm3, ocn3, org1)
      )
      expect(rpt.matching_ht_items.to_a.size).to eq 3
    end
    it "returns fewer records if date criterion restricts" do
      rpt_21 = described_class.new(
        ht_item_ids_file: ht_item_ids_file,
        start_date: "2021-06-01"
      )
      cluster_tap_save(
        build_item(itm1, ocn1, org1),
        build_item(itm2, ocn2, org1),
        build_item(itm3, ocn3, org1)
      )
      expect(rpt_21.matching_ht_items.to_a.size).to eq 1
    end
  end
  describe "#holders_minus_contributor" do
    it "returns empty string if nobody holds" do
      item = build_item(itm1, ocn1, org1)
      cluster_tap_save item
      other_holders = rpt.holders_minus_contributor(Cluster.find_by(ocns: ocn1), org1)
      expect(other_holders).to eq ""
    end
    it "returns empty string if only contributor holds" do
      item = build_item(itm1, ocn1, org1)
      cluster_tap_save item
      other_holders = rpt.holders_minus_contributor(Cluster.find_by(ocns: ocn1), org1)
      expect(other_holders).to eq ""
    end
    it "returns the holders in a cluster minus the given contributor" do
      item = build_item(itm1, ocn1, org1)
      hol = build(:holding, ocn: ocn1, organization: org2)
      cluster_tap_save(item, hol)
      other_holders = rpt.holders_minus_contributor(Cluster.find_by(ocns: ocn1), org1)
      expect(other_holders).to eq org2
    end
  end
  describe "#matching_clusters" do
    it "returns nothing if there is nothing in the db" do
      expect(rpt.matching_clusters.to_a).to be_empty
    end
    it "returns nothing if there are no matching clusters" do
      cluster_tap_save build_item("test.nomatch123", ocn1, org1)
      expect(rpt.matching_clusters.to_a).to be_empty
    end
    it "returns the matching clusters (based on start_date)" do
      cluster_tap_save(
        build_item(itm1, ocn1, org1),
        build_item(itm2, ocn2, org1),
        build_item(itm3, ocn3, org1)
      )

      # In these 3 tests, start_date goes up
      # and matching_clusters.count goes down
      expect(
        described_class.new(
          start_date: dat1,
          ht_item_ids_file: ht_item_ids_file
        ).matching_clusters.count
      ).to eq 3

      expect(
        described_class.new(
          start_date: dat2,
          ht_item_ids_file: ht_item_ids_file
        ).matching_clusters.count
      ).to eq 2

      expect(
        described_class.new(
          start_date: dat3,
          ht_item_ids_file: ht_item_ids_file
        ).matching_clusters.count
      ).to eq 1
    end
  end
  describe "#item_ids_src" do
    it "returns method to call based on @ht_item_ids_file" do
      # rpt has a file set, so file
      expect(rpt.item_ids_src).to eq :matching_item_ids_from_file
      # ht_item_ids_file defaults to nil, which gives db
      expect(described_class.new.item_ids_src).to eq :matching_item_ids_from_db
    end
  end
  describe "#matching_item_ids" do
    it "returns nothing if there are no item_ids matching the criteria" do
      # Either because there is nothing in the file:
      # (there should be zero matching items in /dev/null)
      expect(
        described_class.new(
          start_date: dat1,
          ht_item_ids_file: "/dev/null"
        ).matching_item_ids.to_a
      ).to be_empty
      # Or because the start_date criterion restricts it to nothing
      expect(
        described_class.new(
          start_date: datZ,
          ht_item_ids_file: ht_item_ids_file
        ).matching_item_ids.to_a
      ).to be_empty
    end
    it "returns records matching criteria" do
      cluster_tap_save(
        build_item(itm1, ocn1, org1),
        build_item(itm2, ocn2, org1),
        build_item(itm3, ocn3, org1)
      )
      expect(
        described_class.new(
          start_date: dat1,
          ht_item_ids_file: ht_item_ids_file
        ).matching_item_ids.to_a.size
      ).to eq 3
      expect(
        described_class.new(
          start_date: dat3,
          ht_item_ids_file: ht_item_ids_file
        ).matching_item_ids.to_a.size
      ).to eq 1
    end
  end
  describe "#run" do
    it "generates a report" do
      # Put 3 items and one holding in the db.
      cluster_tap_save(
        build_item(itm1, ocn1, org1),
        build_item(itm2, ocn2, org1),
        build_item(itm3, ocn3, org1),
        build(:holding, ocn: ocn3, organization: org2)
      )
      # File pops into existence upon rpt.run
      expect(File.exist?(outf)).to be false
      expect { rpt.run }.not_to raise_error
      # Now it exists.
      expect(File.exist?(outf)).to be true
      lines = File.read(outf).split("\n")
      expect(lines.size).to eq 4
      # It starts with a header
      expect(lines.shift).to eq rpt.header
      expect(lines.shift).to eq [org1, itm1, "allow", dat1, ""].join("\t")
      expect(lines.shift).to eq [org1, itm2, "allow", dat2, ""].join("\t")
      expect(lines.shift).to eq [org1, itm3, "allow", dat3, org2].join("\t")
      expect(lines.shift).to eq nil # FIN
    end
  end
end
