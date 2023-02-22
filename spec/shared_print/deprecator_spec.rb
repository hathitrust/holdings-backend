# frozen_string_literal: true

require "spec_helper"
require "shared_print/deprecator"
require "fileutils"
require "phctl"

RSpec.describe SharedPrint::Deprecator do
  let(:org_1) { "umich" }
  let(:org_2) { "smu" }
  let(:ocn_1) { 111 }
  let(:local_id_1) { "i111" }
  let(:status_1) { "E" }
  let(:dep) { described_class.new }
  let(:empty_cluster) { create(:cluster) }

  def make_commitment(ocn, org, local_id)
    # Make and cluster a commitment
    com = build(:commitment, ocn: ocn, organization: org, local_id: local_id)
    cluster = Clustering::ClusterCommitment.new(com).cluster.tap(&:save)
    cluster.commitments.first
  end

  def lookup_commitment(ocn)
    Cluster.where(ocns: ocn).first.commitments.first
  end

  before(:each) do
    Cluster.collection.find.delete_many
    dep.clear_err
  end

  describe "#check_header" do
    it "neg" do
      expect(dep.check_header("")).to be false
      expect(dep.check_header("foo")).to be false
      expect(dep.err.size).to eq 2
    end

    it "pos" do
      hed = "organization\tocn\tlocal_id\tdeprecation_status"
      expect(dep.check_header(hed)).to be true
      expect(dep.err.size).to eq 0
    end
  end

  it "putting it all together, deprecates a matching record" do
    make_commitment(ocn_1, org_1, local_id_1)
    expect(lookup_commitment(ocn_1).deprecated?).to be false
    line = [org_1, ocn_1, local_id_1, status_1].join("\t")
    dep.try_deprecate(line)
    expect(lookup_commitment(ocn_1).deprecated?).to be true
    expect(dep.err.size).to eq 0
  end

  it "satisfies the acceptance criteria" do
    # Copied from the ticket: https://tools.lib.umich.edu/jira/browse/HT-3265
    # 1  |This is done when a member of HT staff can take a file of deprecation records submitted by a
    # 2  |member (HT-2097), run it through a command and get all matching commitments deprecated.
    # 3  |It should report back which commitments were deprecated, their new deprecation status+date,
    # 4  |and any records in the file that did not (for whatever reason) match a commitment.
    # 5  |Scenario:
    # 6  |Database contains commitments A, B, C, & D.
    # 7  |Member submits a file to deprecate C, D, E, F.
    # 8  |Staff runs the command on the file.
    # 9  |C & D match and are deprecated.
    # 10 |E & F do not match and are not deprecated.
    # 11 |Report contains the info that C & D were deprecated (with the given status on the given date)
    # 12 |... and that E & F could not be matched and were not deprecated.

    # Make sure there are commitments in the DB (#6)
    make_commitment(1, org_1, "A")
    make_commitment(2, org_1, "B")
    make_commitment(3, org_1, "C")
    make_commitment(4, org_1, "D")
    make_commitment(5, org_2, "E")
    make_commitment(6, org_2, "F")
    # Make a deprecation file (#7)
    deprecation_file_path = "#{ENV["TEST_TMP"]}/acceptance_criteria_file.tsv"
    File.open(deprecation_file_path, "w") do |f|
      f.puts "organization\tocn\tlocal_id\tdeprecation_status"
      f.puts "umich\t3\tC\tM"
      f.puts "umich\t4\tD\tM"
      f.puts "umich\t5\tE\tM"
      f.puts "umich\t6\tF\tM"
    end
    expect(File.file?(deprecation_file_path)).to be true
    # Run command on file (#8)
    PHCTL::PHCTL.start(["sp", "deprecate", deprecation_file_path])
    # C & D are deprecated (#9)
    expect(lookup_commitment(3).deprecated?).to be true
    expect(lookup_commitment(4).deprecated?).to be true
    # E & F are not deprecated (#10)
    expect(lookup_commitment(5).deprecated?).to be false
    expect(lookup_commitment(6).deprecated?).to be false
    # (... nor are A & B by the way, although missing from the acceptance criteria)
    expect(lookup_commitment(1).deprecated?).to be false
    expect(lookup_commitment(2).deprecated?).to be false

    report_slurp = File.read(Dir.glob("#{ENV["TEST_TMP"]}/deprecation_report/commitments_deprecator_*").first).split("\n")
    # We logged what we did and what we could not do (#11 & 12).
    today = Date.today.strftime("%Y-%m-%d")
    expect(report_slurp.count { |x| x =~ /Commitment deprecated.+deprecation_date: #{today}/ }).to eq 2
    expect(report_slurp.count { |x| x.start_with?("Something failed:") }).to eq 2
  end
end
