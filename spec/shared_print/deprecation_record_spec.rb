# frozen_string_literal: true

require "spec_helper"
require "shared_print/deprecation_record"

RSpec.describe SharedPrint::DeprecationRecord do
  let(:org) { "umich" }
  let(:org_2) { "smu" }
  let(:ocn) { 111 }
  let(:ocn_that_should_fail) { -999 }
  let(:loc) { "i123" }
  let(:loc_2) { "i222" }
  let(:sta) { "E" }
  let(:status_that_should_fail) { "X" }
  let(:line) { [org, ocn, loc, sta].join("\t") }
  let(:empty_cluster) { create(:cluster) }
  let(:dep) { described_class.new(organization: org, ocn: empty_cluster.ocns.first, local_id: loc, status: sta) }

  def make_commitment(ocn, org, local_id)
    # Make and cluster a commitment
    com = build(:commitment, ocn: ocn, organization: org, local_id: local_id)
    cluster = Clustering::ClusterCommitment.new(com).cluster.tap(&:save)
    cluster.commitments.where(uuid: com.uuid).first
  end

  before(:each) do
    Cluster.collection.find.delete_many
  end

  describe "#initialize" do
    it "generates a #{described_class} given valid args" do
      expect do
        described_class.new(
          organization: org,
          ocn: ocn,
          local_id: loc,
          status: sta
        )
      end.not_to raise_error
    end

    it "raises an error if given any invalid args (currently only status can cause an error to be raised)" do
      expect do
        described_class.new(
          organization: org,
          ocn: ocn,
          local_id: loc,
          status: status_that_should_fail
        )
      end.to raise_error ArgumentError
    end
  end

  describe "#to_s" do
    it "stringifies the way we expect" do
      expect(dep.to_s).to eq "ocn:#{empty_cluster.ocns.first}, organization:#{org}, local_id:#{loc}, status:#{sta}"
    end
  end

  describe "#self.parse_line" do
    it "parses a line into a #{described_class} if given a line that can be parsed" do
      line = [org, ocn, loc, sta].join("\t")
      parsed = described_class.parse_line(line)
      expect(parsed).to be_a described_class
      expect(parsed.ocn).to eq ocn
      expect(parsed.organization).to eq org
      expect(parsed.local_id).to eq loc
      expect(parsed.status).to eq sta
    end

    it "raises an error if the given line contains elements that cause validate to raise an error" do
      line_that_should_fail = [org, ocn, loc, status_that_should_fail].join("\t")
      expect { described_class.parse_line(line_that_should_fail) }.to raise_error ArgumentError
    end
  end

  describe "#cluster" do
    it "finds a cluster if there is a cluster to find" do
      expect(dep.cluster).to be_a Cluster
      expect(dep.err.size).to eq 0
    end

    it "does not find a cluster if there is no matching cluster, and notes this in @err" do
      dep = described_class.new(ocn: ocn_that_should_fail, status: sta)
      expect(dep.cluster).to eq nil
      expect(dep.err).to eq ["No cluster found for OCN:#{ocn_that_should_fail}"]
    end
  end

  describe "#commitments" do
    it "finds commitments if there are commitments on the cluster" do
      dep = described_class.new(organization: org, ocn: ocn, local_id: loc, status: sta)
      make_commitment(ocn, org, loc)
      expect(dep.commitments.size).to eq 1
      expect(dep.commitments.first).to be_a Clusterable::Commitment
      expect(dep.err.size).to eq 0
    end

    it "does not find commitments if there are no commitments on the cluster" do
      dep = described_class.new(organization: org, ocn: empty_cluster.ocns.first, local_id: loc, status: sta)
      expect(dep.commitments.size).to eq 0
      expect(dep.err.size).to eq 1
    end
  end

  describe "#org_commitments" do
    it "finds commitments that belong to its organization if there are any in its cluster" do
      comm = make_commitment(ocn, org, loc)
      dep = described_class.new(organization: org, ocn: ocn, local_id: loc, status: sta)
      expect(dep.org_commitments).to eq [comm]
      expect(dep.err.size).to eq 0
    end

    it "does not find commitments that belong to its organization if there aren't any" do
      make_commitment(ocn, org, loc)
      dep = described_class.new(organization: org_2, ocn: ocn, local_id: loc, status: sta)
      expect(dep.org_commitments.size).to eq 0
      expect(dep.err).to eq ["No commitments by organization:#{org_2} in cluster."]
    end
  end

  describe "#reject_deprecated" do
    it "rejects deprecated commitments from its org_commitments" do
      com1 = make_commitment(ocn, org, loc)
      com2 = make_commitment(ocn, org, loc_2)
      com2.deprecate(status: "E")
      expect(com1.deprecated?).to be false
      expect(com2.deprecated?).to be true
      com2._parent.save
      dep = described_class.new(organization: org, ocn: ocn, local_id: loc, status: sta)
      expect(dep.reject_deprecated).to eq [com1]
    end

    it "_only_ rejects deprecated commitments" do
      com1 = make_commitment(ocn, org, loc)
      com2 = make_commitment(ocn, org, loc_2)
      dep = described_class.new(organization: org, ocn: ocn, local_id: loc, status: sta)
      expect(dep.reject_deprecated).to eq [com1, com2]
    end
  end

  describe "#local_id_matches" do
    it "only returns commitments that match its local_id" do
      make_commitment(ocn, org, loc)
      make_commitment(ocn, org, loc_2)
      dep = described_class.new(organization: org, ocn: ocn, local_id: loc, status: sta)
      expect(dep.local_id_matches.size).to eq 1
      expect(dep.local_id_matches.first.local_id).to eq loc
    end
  end

  describe "#multiple_matches?" do
    it "reports the occurrence of multiple local_id matches" do
      make_commitment(ocn, org, loc)
      make_commitment(ocn, org, loc)
      dep = described_class.new(organization: org, ocn: ocn, local_id: loc, status: sta)
      dep.multiple_matches?
      expect(dep.err.size).to eq 3
    end
  end
end