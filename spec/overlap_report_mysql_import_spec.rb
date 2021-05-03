# frozen_string_literal: true

require "spec_helper"
require "cluster_ht_item"
require "cluster_holding"
require "cluster_overlap"
require "single_part_overlap"
require "multi_part_overlap"
require "serial_overlap"
require_relative "../bin/export_overlap_report"
require "tempfile"

RSpec.describe "overlap_report_import_to_mysql" do
  let(:connection) { HoldingsDB.new }
  let(:load_script) { Pathname.new(__dir__).parent + "bin" + "load_overlap_report_to_database.rb" }

  def tempfilepath
    "/tmp/tmp_load_test"
  end

  # Build up a couple items and save them using the export logic from bin/export_overlap_report
  around(:each) do |spec|
    h   = build(:holding)
    ht  = build(:ht_item, ocns: [h.ocn], billing_entity: "not_same_as_holding")
    ht2 = build(:ht_item, billing_entity: "not_same_as_holding")
    Cluster.each(&:delete)
    ClusterHolding.new(h).cluster.tap(&:save)
    ClusterHtItem.new(ht).cluster.tap(&:save)
    ClusterHtItem.new(ht2).cluster.tap(&:save)

    org = nil # all orgs
    File.open(tempfilepath, "w:utf-8") do |tmpfile|
      ClusterOverlap.matching_clusters(org).each do |c|
        ClusterOverlap.new(c, org).each do |overlap|
          tmpfile.puts overlap_line(overlap.to_hash)
        end
      end
    end

    spec.run

    # File.unlink(tempfilepath)
  end

  describe "Sanity check" do
    let(:lines) { File.open(tempfilepath).to_a.map {|x| x.split("\t") } }

    it "has 3 lines" do
      expect(lines.size).to equal(3)
    end

    it "has lines with 10 columns" do
      expect(lines.map(&:size)).to all(be == 10)
    end
  end

  describe "bulk import" do
    it "loads a little file via code" do
      connection[:holdings_htitem_htmember].delete
      d = connection.load_tab_delimited_file(tablename: "holdings_htitem_htmember",
                                             filepath: tempfilepath)
      expect(d).to eq(3)
      expect(connection[:holdings_htitem_htmember].count).to eq(3)
      connection[:holdings_htitem_htmember].delete
    end

    it "loads a little file via the script" do
      connection[:holdings_htitem_htmember].delete
      system("bundle exec ruby #{load_script} #{tempfilepath}")
      expect(connection[:holdings_htitem_htmember].count).to eq(3)
    end
  end
end
