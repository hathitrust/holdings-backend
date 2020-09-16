# frozen_string_literal: true

require "spec_helper"
require "cluster_ht_item"
require "tmpdir"

class InstrumentedClusterHtItem < ClusterHtItem

  def initialize(htitems = [], pid:, tmpdir:, wait_before_merge: nil,
    wait_before_save: nil, wait_before_delete: nil)
    super(htitems)
    @pid = pid
    @wait_before_merge = wait_before_merge
    @wait_before_save = wait_before_save
    @wait_before_delete = wait_before_delete
    @tmpdir = tmpdir
  end

  def cluster_for_ocns
    wait_for(@wait_before_merge)

    super.tap do |_c|
      write_status("#{@pid}_got_cluster")
      wait_for(@wait_before_save)
    end
  end

  def cluster_with_htitem(htitem)
    super.tap do |c|
      puts "before delete: htitems from #{c}: #{c&.ht_items&.inspect}"
      write_status("#{@pid}_got_cluster")
      wait_for(@wait_before_delete)
    end
  end


  def cluster
    super.tap do |_c|
      write_status("#{@pid}_saved_cluster")
    end
  end

  def write_status(file)
    puts "#{@pid} writing status #{file}"
    File.open("#{@tmpdir}/#{file}", "w") {|_| }
  end

  def wait_for(file)
    puts "#{@pid} waiting on #{file}"
    return unless file

    sleep(0.05) until File.exist?("#{@tmpdir}/#{file}")
  end
end

RSpec.describe "concurrency" do
  def run_concurrent(first_process,second_process)
    Dir.mktmpdir do |tmpdir|
      fork do
        second_process.call(tmpdir)
      end
      first_process.call(tmpdir)
      Process.wait
    end

    setup_mongo
    #Cluster.all.each {|c| puts JSON.pretty_generate(JSON.parse(c.to_json)) }
  end

  def setup_mongo
    Mongoid.load!("mongoid.yml", :test)
    Cluster.create_indexes
  end

  before(:each) do
    Cluster.each(&:delete)
  end

  context "when a process writes an htitem into a cluster that was deleted in another process" do

    let(:first_process) do
      Proc.new do |tmpdir|
        setup_mongo
        create(:cluster, ocns: [1])
        create(:cluster, ocns: [2])

        ht_item = FactoryBot.build(:ht_item, ocns: [2])

        InstrumentedClusterHtItem.new(ht_item, pid: "first",
                                        wait_before_save: "second_got_cluster",
                                        tmpdir: tmpdir).cluster
      end
    end

    let(:second_process) do
      Proc.new do |tmpdir|
        setup_mongo
        ht_item = FactoryBot.build(:ht_item, ocns: [1, 2])

        InstrumentedClusterHtItem.new(ht_item, pid: "second",
                                   wait_before_merge: "first_got_cluster",
                                   wait_before_save: "first_saved_cluster",
                                   tmpdir: tmpdir).cluster
      end
    end

    it "doesn't lose the htitem" do
      run_concurrent(first_process, second_process)
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ocns).to contain_exactly(1, 2)
      expect(Cluster.first.ht_items.count).to eq(2)
    end
  end

  context "when a process writes an htitem into a cluster that will be reclustered" do
    # Reclusterer race condition potential scenario
    #   - Process 1 gets a handle to the cluster and reads the htitems
    #   - Process 2 adds an htitem to the cluster
    #   - Process 1 deletes a different htitem and calls reclusterer
    #   - Ensure the htitem added by process 2 hasn't disappeared

    let(:first_ht_item)  { FactoryBot.build(:ht_item, ocns: [1,2]) }
    let(:second_ht_item) { FactoryBot.build(:ht_item, ocns: [1]) }

    let(:first_process) do
      Proc.new do |tmpdir|
        setup_mongo
        ocns = first_ht_item.ocns
        puts "first saving cluster"
        ClusterHtItem.new(first_ht_item).cluster.save

        puts "first starting instrumentcluster"

        InstrumentedClusterHtItem.new(first_ht_item, pid: "first",
                                     wait_before_delete: "second_saved_cluster",
                                     tmpdir: tmpdir).delete

      end
    end

    let(:second_process) do
      Proc.new do |tmpdir|
        setup_mongo

        InstrumentedClusterHtItem.new(second_ht_item, pid: "second",
                                   wait_before_save: "first_got_cluster",
                                   tmpdir: tmpdir)
          .cluster
      end
    end

    it "doesn't lose the htitem added by the second process" do
      run_concurrent(first_process, second_process)
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ocns).to contain_exactly(1)
      expect(Cluster.first.ht_items.count).to eq(1)
    end
  end
end
