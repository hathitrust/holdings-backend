# frozen_string_literal: true

require "spec_helper"
require "services"
require "cluster_ht_item"
require "tmpdir"

class Synchronizer
  def initialize(pid:, tmpdir:, wait_before: {})
    @pid = pid
    @wait_before = wait_before
    @tmpdir = tmpdir
  end

  def write_status(action)
    Services.logger.debug "#{@pid} writing status #{@pid}_#{action}"
    File.open("#{@tmpdir}/#{@pid}_#{action}", "w") {|_| }
  end

  def wait_for(condition)
    file = @wait_before[condition]
    return unless file

    Services.logger.debug "#{@pid} waiting on #{file}"

    sleep(0.05) until File.exist?("#{@tmpdir}/#{file}")
  end
end

class InstrumentedClusterGetter < ClusterGetter

  def initialize(ocns, synchronizer)
    super(ocns)
    @synchronizer = synchronizer
  end

  def get
    @synchronizer.wait_for(:merge)

    super do |c|
      @synchronizer.write_status("got_cluster")
      @synchronizer.wait_for(:save)
      yield c
    end
  end

end

class InstrumentedClusterHtItem < ClusterHtItem

  def with_synchronizer(synchronizer)
    tap { @synchronizer = synchronizer }
  end

  def cluster
    super(getter: InstrumentedClusterGetter.new(@ocns, @synchronizer)).tap do
      @synchronizer.write_status("saved_cluster")
    end
  end

  def cluster_with_htitem(htitem)
    super.tap do |c|
      Services.logger.debug "before delete: htitems from #{c}: #{c&.ht_items&.inspect}"
      @synchronizer.write_status("got_cluster")
      @synchronizer.wait_for(:delete)
    end
  end
end

RSpec.describe "concurrency" do
  def reconnect_mongoid
    # from https://docs.mongodb.com/mongoid/current/tutorials/mongoid-configuration/
    Mongoid::Clients.clients.each do |_name, client|
      client.close
      client.reconnect
    end
  end

  def run_concurrent(first_process, second_process)
    Mongoid.disconnect_clients
    Dir.mktmpdir do |tmpdir|
      fork do
        reconnect_mongoid
        second_process.call(tmpdir)
      end
      reconnect_mongoid
      first_process.call(tmpdir)
      Process.wait
    end
  end

  before(:each) do
    Cluster.each(&:delete)
  end

  context "when a process writes an htitem into a cluster that was deleted in another process" do
    let(:first_process) do
      proc do |tmpdir|
        create(:cluster, ocns: [1])
        create(:cluster, ocns: [2])

        ht_item = build(:ht_item, ocns: [2])

        syncher = Synchronizer.new(pid: "first",
                                   wait_before: { save: "second_got_cluster" },
                                   tmpdir: tmpdir)

        InstrumentedClusterHtItem.new(ht_item)
          .with_synchronizer(syncher)
          .cluster
      end
    end

    let(:second_process) do
      proc do |tmpdir|
        ht_item = build(:ht_item, ocns: [1, 2])

        syncher = Synchronizer.new(pid: "second",
                                   wait_before: { merge: "first_got_cluster",
                                                  save:  "first_saved_cluster" },
                                   tmpdir: tmpdir)

        InstrumentedClusterHtItem.new(ht_item)
          .with_synchronizer(syncher)
          .cluster
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

    let(:first_ht_item)  { FactoryBot.build(:ht_item, ocns: [1, 2]) }
    let(:second_ht_item) { FactoryBot.build(:ht_item, ocns: [1]) }

    let(:first_process) do
      proc do |tmpdir|
        ClusterHtItem.new(first_ht_item).cluster.save

        syncher = Synchronizer.new(pid: "first",
                                   wait_before: { delete: "second_saved_cluster" },
                                   tmpdir: tmpdir)

        InstrumentedClusterHtItem.new(first_ht_item)
          .with_synchronizer(syncher)
          .delete
      end
    end

    let(:second_process) do
      proc do |tmpdir|
        syncher = Synchronizer.new(pid: "second",
                                   wait_before: { save: "first_got_cluster" },
                                   tmpdir: tmpdir)

        InstrumentedClusterHtItem.new(second_ht_item)
          .with_synchronizer(syncher)
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
