# frozen_string_literal: true

require "spec_helper"
require "pp"
require_relative "../bin/export_etas_overlap_report"

RSpec.describe "etas_overlap_report" do
  let(:h) { build(:holding) }
  let(:ht) { build(:ht_item, ocns: [h.ocn], access: "deny") }
  let(:ht2) { build(:ht_item, access: "deny") }
  let(:orgs) { [h.organization, ht.billing_entity, ht2.billing_entity].uniq }

  before(:each) do
    Cluster.each(&:delete)
    ClusterHolding.new(h).cluster.tap(&:save)
    ClusterHtItem.new(ht).cluster.tap(&:save)
    ClusterHtItem.new(ht2).cluster.tap(&:save)
    reports = {}
    orgs.each do |org|
      reports[org] = File.open("tmp_etas_#{org}", "w")
    end
    ClusterOverlap.matching_clusters(nil).each do |c|
      ClusterOverlap.new(c, nil).each do |overlap|
        overlap.matching_holdings.each do |holding|
          etas_record = ETASOverlap.new(ocn: holding[:ocn],
                                        local_id: holding[:local_id],
                                        item_type: c.format,
                                        access: overlap.ht_item.access,
                                        rights: overlap.ht_item.rights)
          reports[holding[:organization]].puts etas_record
        end
      end
    end
    reports.each {|_org, f| f.close }
  end

  it "has a file for each organization" do
    orgs.each do |org|
      expect(File.exist?("tmp_etas_#{org}")).to be true
    end
  end

  it "has 1 line in the holding member" do
    lines = File.open("tmp_etas_#{h.organization}").to_a
    expect(lines.size).to eq(1)
  end

  it "has 5 columns in the report" do
    orgs.each do |org|
      lines = File.open("tmp_etas_#{org}").to_a.map {|x| x.split("\t") }
      expect(lines.map(&:size)).to all(be == 5)
    end
  end
end
