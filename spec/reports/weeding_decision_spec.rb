# frozen_string_literal: true

require "spec_helper"
require "reports/weeding_decision"

RSpec.describe Reports::WeedingDecision do
  let(:org1) { "umich" }
  let(:org2) { "smu" }
  let(:rpt) { described_class.new(org1) }
  let(:access_map) { {true => "allow", false => "deny"} }

  before(:each) do
    # Leave no files
    outf = rpt.outf
    if File.exist?(outf)
      FileUtils.rm(outf)
    end
  end

  after(:all) do
    Cluster.collection.find.delete_many
  end

  describe "#initialize" do
    it "requires an organization" do
      expect(rpt).to be_a Reports::WeedingDecision
    end
    it "fails otherwise" do
      expect { described_class.new }.to raise_error ArgumentError
    end
  end

  describe "#run" do
    it "generates an outfile" do
      outf = rpt.outf
      expect(File.exist?(outf)).to be false
      rpt.run
      expect(File.exist?(outf)).to be true
    end
  end

  describe "#header" do
    it "looks like this" do
      # just so if we change the header, we know to also change the test
      reference_header = "ocn\tlocal_id\topen_items\tclosed_items\tlocal_copies\tnum_orgs_holding\tlocal_commitments\tall_commitments"
      expect(rpt.header).to eq reference_header
    end
  end

  describe "#body" do
    # For these tests, build some clusters with varying data.
    # When built like this, rpt.run should make a report with ocns 8 & 10.
    before(:each) do
      Cluster.collection.find.delete_many
      buildables = []

      # Building 10 clusters. 8 & 10 should match criteria if running for org1
      # cluster_ocn  |open_items  |closed_items  |umich_holdings  |umich_commitments  |smu_commitments
      # 1            |0           |0             |1               |0                  |0
      # 2            |0           |0             |1               |0                  |0
      # 3            |0           |0             |1               |0                  |0
      # 4            |1           |0             |1               |0                  |0
      # 5            |0           |1             |1               |0                  |0
      # 6            |1           |0             |1               |0                  |0
      # 7            |0           |1             |1               |1                  |0
      # 8*           |1           |0             |1               |1                  |0
      # 9            |0           |1             |1               |1                  |1
      # 10*          |1           |0             |1               |1                  |1
      #
      # rpt.run should, if the db matches buildables, produce the output file:
      # ocn  |local_id  |open_items  |closed_items  |local_copies  |num_orgs_holding  |local_commitments  |all_commitments
      # 8    |i_8       |1           |0             |1             |1                 |1                  |umich:1
      # 10   |i_10      |1           |0             |1             |1                 |1                  |umich:1, smu:1

      1.upto(10).each do |i|
        buildables << build(:holding, ocn: i, local_id: "i_#{i}", organization: org1) if i > 0
        buildables << build(:ht_item, ocns: [i], access: access_map[i.even?]) if i > 3
        buildables << build(:commitment, ocn: i, organization: org1) if i > 6
        buildables << build(:commitment, ocn: i, organization: org2) if i > 8
      end
      cluster_tap_save buildables
    end

    it "provides the data" do
      enum = rpt.body
      expect(enum).to be_a Enumerator
      ocns = [8, 10] # check that these are the ocns that appear, in that order
      enum.each do |rec|
        expected_ocn = ocns.shift
        expect(rec).to be_a Reports::WeedingRecord
        expect(rec.ocn).to eq expected_ocn
        expect(rec.local_id).to eq "i_#{expected_ocn}"
      end
    end
    it "skips a cluster that does not have holdings" do
      # Normal case.
      expect(rpt.body.map { |rec| rec.ocn }).to eq [8, 10]
      # Delete holdings from cluster 8
      Cluster.where(ocns: 8).first.holdings.first.delete
      expect(rpt.body.map(&:ocn)).to eq [10]
    end
    it "skips a cluster that does not have (open) ht_items" do
      # Normal case.
      expect(rpt.body.map(&:ocn)).to eq [8, 10]
      # Delete holdings from cluster 8
      Cluster.where(ocns: 8).first.ht_items.first.delete
      expect(rpt.body.map(&:ocn)).to eq [10]
      # Adding a closed item won't change anything
      cluster_tap_save [build(:ht_item, ocns: [8], access: "deny")]
      expect(rpt.body.map(&:ocn)).to eq [10]
      # cluster 10 must have 1+ open items before it qualifies
      cluster_tap_save [build(:ht_item, ocns: [8], access: "allow")]
      expect(rpt.body.map(&:ocn)).to eq [8, 10]
    end
    it "skips a cluster that does not have commitments" do
      Cluster.where(ocns: 8).first.ht_items.first.delete
      ocns = [10] # check that these are the ocns that appear, in that order
      expect(rpt.body.map(&:ocn)).to eq ocns
    end

    # Runs a report and returns line matching ocn, for tests below
    def rpt_ocn(rpt, find_ocn)
      rpt.body.find { |rec| rec.ocn == find_ocn }
    end

    it "tracks open and closed items on cluster" do
      ocn = 8
      # initial state, 0 open & 1 closed
      expect(rpt_ocn(rpt, ocn).open_items).to eq 1
      expect(rpt_ocn(rpt, ocn).closed_items).to eq 0
      # incr open_items, expect 1 open & 1 closed
      cluster_tap_save [build(:ht_item, ocns: [ocn], access: "allow")]
      expect(rpt_ocn(rpt, ocn).open_items).to eq 2 # ++
      expect(rpt_ocn(rpt, ocn).closed_items).to eq 0
      # incr closed_items, expect 1 open & 2 closed
      cluster_tap_save [build(:ht_item, ocns: [ocn], access: "deny")]
      expect(rpt_ocn(rpt, ocn).open_items).to eq 2
      expect(rpt_ocn(rpt, ocn).closed_items).to eq 1 # ++
    end
    it "tracks local_copies" do
      ocn = 8
      # initial state, local_copies = 1 (1 is lowest)
      expect(rpt_ocn(rpt, ocn).local_copies).to eq 1
      expect(rpt.body.count).to eq 2 # ocns 8 and 10
      # Add another holding for that ocn, and expect local_copies to go up
      # without adding another line to the report
      cluster_tap_save [build(:holding, ocn: ocn, local_id: "i_#{ocn}", organization: org1)]
      expect(rpt_ocn(rpt, ocn).local_copies).to eq 2 # ++
      expect(rpt.body.count).to eq 2 # no ++
      # Add another holding for that ocn, and expect local_copies to go up
      # without adding another line to the report
      cluster_tap_save [build(:holding, ocn: ocn, local_id: "i_#{ocn}", organization: org1)]
      expect(rpt_ocn(rpt, ocn).local_copies).to eq 3 # ++
      expect(rpt.body.count).to eq 2 # no ++
    end
    it "tracks num_orgs_holding" do
      ocn = 8
      expect(rpt_ocn(rpt, ocn).num_orgs_holding).to eq 1
      # Adding a holding by another member should incr
      cluster_tap_save [build(:holding, ocn: ocn, organization: org2)]
      expect(rpt_ocn(rpt, ocn).num_orgs_holding).to eq 2 # ++
      # Adding a holding by same member should NOT incr
      cluster_tap_save [build(:holding, ocn: ocn, organization: org2)]
      expect(rpt_ocn(rpt, ocn).num_orgs_holding).to eq 2 # no ++
    end
    it "tracks local_commitments" do
      ocn = 8
      # initial state, local_commitments = 1 (1 is lowest)
      expect(rpt_ocn(rpt, ocn).local_commitments).to eq 1
      expect(rpt.body.count).to eq 2
      # Add another commitment for that ocn, and expect local_commitments to go up
      # without adding another line to the report
      cluster_tap_save [build(:commitment, ocn: ocn, organization: org1)]
      expect(rpt_ocn(rpt, ocn).local_commitments).to eq 2 # ++
      expect(rpt.body.count).to eq 2 # no ++
      # Add another commitment for that ocn, and expect local_commitments to go up
      # without adding another line to the report
      cluster_tap_save [build(:commitment, ocn: ocn, organization: org1)]
      expect(rpt_ocn(rpt, ocn).local_commitments).to eq 3 # ++
      expect(rpt.body.count).to eq 2 # no ++
    end
    it "tracks commitments_tally" do
      ocn = 10
      # initial state, commitments_tally = umich:1, smu:1
      expect(rpt_ocn(rpt, ocn).commitments_tally.sort).to eq([[org2, 1], [org1, 1]])
      # add a umich commitment
      cluster_tap_save [build(:commitment, ocn: ocn, organization: org1)]
      expect(rpt_ocn(rpt, ocn).commitments_tally.sort).to eq([[org2, 1], [org1, 2]])
      # add a smu commitment
      cluster_tap_save [build(:commitment, ocn: ocn, organization: org2)]
      expect(rpt_ocn(rpt, ocn).commitments_tally.sort).to eq([[org2, 2], [org1, 2]])
    end
  end
end
