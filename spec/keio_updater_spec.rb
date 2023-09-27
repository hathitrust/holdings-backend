# frozen_string_literal: true

require "spec_helper"
require "keio_updater"

RSpec.describe KeioUpdater do
  let(:lil_k) { "keio" }
  let(:big_k) { "KEIO" }
  let(:hword) { "hathitrust" }
  let(:upenn) { "upenn" }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  def build_cluster(ocn)
    ht_item = build(:ht_item, ocns: [ocn], collection_code: big_k, billing_entity: hword)
    ht_item2 = build(:ht_item, ocns: [ocn], collection_code: "PU", billing_entity: upenn)
    create(:cluster, ocns: [ocn])
    cluster_tap_save(ht_item, ht_item2)
  end

  def get_all
    Cluster.where.to_a
  end

  def count_billing_entity(clusters, billing_entity)
    clusters.map { |x| x.ht_items.map(&:billing_entity) }.flatten.count(billing_entity)
  end

  def run_clusters(max_ocn, limit = nil)
    # Setup
    1.upto(max_ocn).each do |ocn|
      build_cluster(ocn)
    end

    if max_ocn > 100 # Or the count may not be correct >:(
      puts "zzz"
      sleep 3
      puts "huh?! wha!?"
    end

    # I'm using be_within(x).of(y) because on my computer the bigger tests tend to
    # be off by 1-2 when max_ocn ~ 1000. I think it is entirely a timing issue.

    # Pre-check
    all = get_all
    count_hword = count_billing_entity(all, hword)
    count_lil_k = count_billing_entity(all, lil_k)
    count_upenn = count_billing_entity(all, upenn)

    expect(all.size).to eq max_ocn
    expect(count_hword).to be_within(3).of(max_ocn) # Flip these.
    expect(count_lil_k).to be_within(3).of(0) # Flip these.
    expect(count_upenn).to be_within(3).of(max_ocn) # Not these.

    # Action
    described_class.new(limit).run

    # Post-check
    all = get_all
    count_hword = count_billing_entity(all, hword)
    count_lil_k = count_billing_entity(all, lil_k)
    count_upenn = count_billing_entity(all, upenn)

    expect(all.size).to eq max_ocn
    if limit.nil?
      expect(count_hword).to be_within(3).of(0) # These flipped.
      expect(count_lil_k).to be_within(3).of(max_ocn) # These flipped.
    else
      expect(all.size).to eq max_ocn
      expect(count_hword).to be_within(3).of(max_ocn - limit) # These flipped.
      expect(count_lil_k).to be_within(3).of(limit) # These flipped.
    end
    expect(count_upenn).to be_within(3).of(max_ocn) # Not these.
  end

  it "does the thing for all of 10 items" do
    run_clusters(10)
  end
  it "does the thing for 5 of 50 items" do
    run_clusters(50, 5)
  end
  xit "does the thing 100 times" do
    run_clusters(100)
  end
  xit "does the thing 1000 times" do
    run_clusters(1000)
  end
end
