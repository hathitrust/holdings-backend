
# frozen_string_literal: true

require "spec_helper"
require "cluster_ht_item"

RSpec.describe "concurrency" do
  class InstrumentedClusterHtItem < ClusterHtItem
    def initialize(ocns=[],pid:, transaction: true, wait_before_merge: nil,
                  wait_before_save: nil)
      super(ocns,transaction: transaction)
      @pid = pid
      @wait_before_merge = wait_before_merge
      @wait_before_save = wait_before_save
    end

    def cluster_for_ocns
      wait_for(@wait_before_merge)

      super.tap do |c|
        write_status("#{@pid}_got_cluster")
        wait_for(@wait_before_save)
      end
    end

    def cluster(htitems)
      super(htitems).tap do |c|
        write_status("#{@pid}_saved_cluster")
      end
    end

    def write_status(file)
      puts "#{@pid} writing #{file}"
      File.open(file, "w") {|_| }
    end

    def wait_for(file)
      return unless file
      puts "#{@pid} waiting for #{file}"
      sleep(0.05) until File.exist?(file)
      puts "#{file} exists"
    end
  end

  def set_initial_state
    Cluster.each(&:delete)

    ClusterHtItem.new([1]).cluster([]).save
    ClusterHtItem.new([2]).cluster([]).save
  end

  def main
    fork do
      second_process
    end
    first_process
    Process.wait

    setup_mongo

    ## RUN THE EXAMPLE HERE
    puts "After both writes"
    Cluster.all.each {|c| puts JSON.pretty_generate(JSON.parse(c.to_json)) }
  end

  def first_process
    puts "In first process #{$$}"
    setup_mongo
    puts "After setup_mongo"
    set_initial_state
    puts "After set_initial_state"

    ht_item = FactoryBot.build(:ht_item, ocns: [2])

    c = InstrumentedClusterHtItem.new(ht_item.ocns, pid: "first",
                                    wait_before_save: "second_got_cluster")
      .cluster([ht_item])

    c.upsert if c.changed?

  end

  def second_process
    puts "In second process #{$$}"
    setup_mongo
    ht_item = FactoryBot.build(:ht_item, ocns: [1, 2])

    c = InstrumentedClusterHtItem.new(ht_item.ocns, pid: "second",
                               wait_before_merge: "first_got_cluster",
                               wait_before_save: "first_saved_cluster"
                               ).cluster([ht_item])
    c.upsert if c.changed?
  end

  def setup_mongo
    Mongoid.load!("mongoid.yml", :test)
    Cluster.create_indexes
  end


  def cleanup
    ["first_got_cluster",
     "second_got_cluster",
     "first_saved_cluster",
     "second_saved_cluster"].each do |file|
      File.unlink(file)
    end
    Cluster.where(ocns: 1).first.ht_items.each(&:delete)
  end

  context "when a process writes an htitem into a cluster that was deleted in another process" do
    it "doesn't lose the htitem" do
      main
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ocns).to contain_exactly(1,2)
      expect(Cluster.first.htitems.count).to eq(2)
      cleanup
    end
  end
end
