# frozen_string_literal: true

require "spec_helper"
require "clustering/cluster_getter"
class Synchronizer
  attr_reader :logger

  def initialize(logger: Services.logger)
    @statuses = Set.new
    @mutex = Mutex.new
    @logger = logger
  end

  def write_status(id, action)
    @logger.debug "#{Thread.current} adding status #{id}:#{action}"
    @mutex.synchronize do
      @statuses.add([id, action].join(":"))
    end
  end

  def wait_for(action)
    @logger.debug "#{Thread.current} waiting on #{action}"

    sleep(0.05) until @statuses.include?(action)
  end
end

# Uses the synchronizer to record the given ID and the method run
# for find, create, add_additional_ocns, and merge.
#
# Use the "wait_for" array to instruct this instance to wait
# for another instance to run the given method before proceeding, for example:
#
# wait_for: { create: "thread1:find" }
#
# means that this instance should wait for the instance with id thread1 to
# complete the 'find' operation' before this instance does the 'create'
# operation.
class InstrumentedClusterGetter < Clustering::ClusterGetter
  attr_reader :retry_count, :retry_err

  def initialize(ocns, id:, synchronizer:, wait_for: {})
    super(ocns)
    @id = id
    @syncer = synchronizer
    @wait_for = wait_for
  end

  [:find, :create, :add_additional_ocns, :merge].each do |method|
    define_method(method) do |*args|
      @syncer.wait_for(@wait_for[method]) if @wait_for[method]
      super(*args).tap do
        @syncer.write_status(@id, method)
      end
    end
  end

  def transaction_opts
    super.merge(before_retry: ->(num_retries, e) {
      @retry_count = num_retries
      @retry_err = e
    })
  end
end

RSpec.describe Clustering::ClusterGetter do
  let(:ocn1) { 5 }
  let(:ocn2) { 6 }
  let(:ocn3) { 7 }
  let(:ocn4) { 8 }
  let(:ht) { build(:ht_item).to_hash }

  include_context "with cluster ocns table"

  context "with multiple ClusterGetters running in parallel" do
    # useful to have when debugging these specs..
    # let(:syncer) { Synchronizer.new(logger: Logger.new($stdout, level: Logger::DEBUG)) }
    let(:syncer) { Synchronizer.new }

    # We use threading, the Synchronizer, and the InstrumentedClusterGetter to control
    # the sequence of when various things happen across two different transactions
    # to provoke different errors.
    #
    # Sequel is thread-safe by default, so it will use its connection pool to allocate
    # a new connection to each thread.

    # case 1:
    # no clusters exist
    # thread1: [1,2]; thread2: [2]
    # thread1 find, thread2 find -- both get nothing
    # thread1 create - creates [1,2]
    # thread2 create:
    #  * attempts to create [2]
    #  * should get a duplicate key error, retry & get the same cluster as thread1
    it "when two transactions create a cluster with the same OCN with retry enabled, gets the same cluster" do
      getter1 = nil
      getter2 = nil
      cluster1 = nil
      cluster2 = nil

      thread1 = Thread.new do
        getter1 = InstrumentedClusterGetter.new([1, 2],
          id: "thread1", synchronizer: syncer,
          wait_for: {create: "thread2:find"})
        cluster1 = getter1.get
      end

      thread2 = Thread.new do
        getter2 = InstrumentedClusterGetter.new([2],
          id: "thread2", synchronizer: syncer,
          wait_for: {create: "thread1:create"})
        cluster2 = getter2.get
      end

      [thread1, thread2].each { |t| t.join }
      expect(cluster1.id).to eq(cluster2.id)
      expect(cluster1.ocns).to eq(cluster2.ocns)
      expect(getter2.retry_count).to be > 0
      expect(getter2.retry_err).to be_a(Sequel::UniqueConstraintViolation)
    end

    # case 2:
    # cluster [1] exists
    # thread1: [1,2]; thread2: [2]
    # thread1 find -- gets [1]
    # thread2 find -- gets nothing
    # thread1 add_additional_ocns - makes [1,2]
    # thread2 create - gets duplicate key error, should retry & find [1,2]
    it "when one transaction creates a cluster with an OCN and another adds that same OCN to a cluster, both get the same cluster" do
      create(:cluster, ocns: [1])
      cluster1 = nil
      cluster2 = nil
      getter1 = nil
      getter2 = nil

      thread1 = Thread.new do
        getter1 = InstrumentedClusterGetter.new([1, 2],
          id: "thread1", synchronizer: syncer,
          wait_for: {add_additional_ocns: "thread2:find"})
        cluster1 = getter1.get
      end

      thread2 = Thread.new do
        getter2 = InstrumentedClusterGetter.new([2],
          id: "thread2", synchronizer: syncer,
          wait_for: {create: "thread1:add_additional_ocns"})
        cluster2 = getter2.get
      end

      [thread1, thread2].each { |t| t.join }
      expect(cluster1.id).to eq(cluster2.id)
      expect(cluster1.ocns).to eq(cluster2.ocns)
      expect(getter2.retry_count).to be > 0
      expect(getter2.retry_err).to be_a(Sequel::UniqueConstraintViolation)
    end

    # case 3:
    # cluster [1] exists
    # thread1: [1,2]; thread2: [2]
    # thread1 find -- gets [1]
    # thread2 find -- gets nothing
    # thread2 create - makes [2]
    # thread1 add_additional_ocns - gets duplicate key error, should retry & merge
    # thread2 has an outdated cluster id & list of OCNs... but that's probably OK (see below)
    it "when one transaction tries to create a cluster with two OCNs and another tries to make a cluster with one of those OCNs, retries and merges" do
      create(:cluster, ocns: [1])
      cluster1 = nil
      cluster2 = nil
      getter1 = nil
      getter2 = nil

      thread1 = Thread.new do
        expect {
          getter1 = InstrumentedClusterGetter.new([1, 2],
            id: "thread1", synchronizer: syncer,
            wait_for: {add_additional_ocns: "thread2:create"})
          cluster1 = getter1.get
        }.to raise_exception(/merge: not implemented/)
      end

      thread2 = Thread.new do
        getter2 = InstrumentedClusterGetter.new([2],
          id: "thread2", synchronizer: syncer,
          wait_for: {create: "thread1:find"})
        cluster2 = getter2.get
      end

      [thread1, thread2].each { |t| t.join }

      # TODO once merge is implemented -- table should have one cluster with OCNs [1,2]
      # expect(Cluster.first.ocns).to contain_exactly(1,2)
      # expect(Cluster.count).to eq(1)
      # expect(getter1.retry_count).to be > 0
      # expect(getter1.retry_err).to be_a(Sequel::UniqueConstraintViolation)
    end

    # case 4:
    # no cluster exists
    # thread1: [1]; thread2: [1,2]
    # thread1 find -- gets nothing
    # thread2 find -- gets nothing
    # thread1 create - makes [1]
    # thread2 create - gets duplicate key error, should retry & do add_additional_ocns
    # in this case thread1 has a cluster with outdated ocns (but correct cluster ID)... but that's probably OK (see below)
    it "when one transaction creates a cluster with one OCN and another tries to create a cluster with that OCNs and another one, retries and adds the second OCN to the first cluster" do
      cluster1 = nil
      cluster2 = nil
      getter1 = nil
      getter2 = nil

      thread1 = Thread.new do
        getter1 = InstrumentedClusterGetter.new([1],
          id: "thread1", synchronizer: syncer,
          wait_for: {create: "thread2:find"})
        cluster1 = getter1.get
      end

      thread2 = Thread.new do
        getter2 = InstrumentedClusterGetter.new([1, 2],
          id: "thread2", synchronizer: syncer,
          wait_for: {create: "thread1:create"})
        cluster2 = getter2.get
      end

      [thread1, thread2].each { |t| t.join }

      expect(Cluster.first.ocns).to contain_exactly(1, 2)
      expect(Cluster.count).to eq(1)

      expect(cluster1.id).to eq(cluster2.id)
      expect(getter2.retry_count).to be > 0
      expect(getter2.retry_err).to be_a(Sequel::UniqueConstraintViolation)
    end

    # Case 3 and 4 demonstrate that we shouldn't use the returned cluster ID or
    # list of OCNs from ClusterGetter to *do* anything. The purpose of
    # ClusterGetter is really just to make it so that the given OCNs are in the
    # *same cluster*. We should never call ClusterGetter.get in a situation
    # where we're only *reading* data as ClusterGetter.get will *modify* the
    # OCN clustering table. This is an argument for e.g. Cluster.cluster_ocns!
    # as the interface name.
    #
    # When we're only *reading* data it's certainly possible the clustering
    # will be modified as we do that, which could result in inconsistency
    # within a report -- but that shouldn't cause incorrectly *written* data.
    # If we care about that we could do the entire report inside a transaction
    # isolated with REPEATABLE READ (or dump the table inside the scope of this
    # kind of transaction, and then read it into memory, so we get a consistent
    # view of it), or something else to ensure a consistent view of the
    # clustering.
    #
    # When we *write* data, we should make sure we aren't using the returned ID
    # from ClusterGetter.get to do anything (again a reason for renaming this)
    # -- this is probably mainly a concern with the "production holdings table"
    # if we need to materialize that rather than having it as a view.

    # When we re-implement delete/recluster, we also need to consider the cases of
    # reclusters and merges happening simultaneously -- for example, if we have
    # an HT item update that causes a recluster, and simultaneously an OCN
    # resolution update the restores the 'glue' - we would want ultimately the
    # cluster to be merged.

    # Likewise, if one transaction adds something that would cause a merge, and
    # another transaction does a recluster, we would want the merged thing to
    # still be there in the end and the cluster to stay together.
  end

  xcontext "when merging two clusters" do
    let(:c1) { create(:cluster, ocns: [ocn1]) }
    let(:c2) { create(:cluster, ocns: [ocn2]) }
    let(:htitem1) { build(:ht_item, ocns: [ocn1]).to_hash }
    let(:htitem2) { build(:ht_item, ocns: [ocn2]).to_hash }
    let(:holding1) { build(:holding, ocn: ocn1).attributes }
    let(:holding2) { build(:holding, ocn: ocn2).attributes }
    let(:ocn_resolution1) { build(:ocn_resolution, resolved: ocn1, deprecated: ocn3).attributes }
    let(:ocn_resolution2) { build(:ocn_resolution, resolved: ocn2, deprecated: ocn4).attributes }

    let(:merged_cluster) { described_class.new([ocn1, ocn2]).get }

    it "combines ocns sets" do
      c1
      c2
      expect(merged_cluster.ocns).to contain_exactly(ocn1, ocn2)
    end

    it "combines holdings" do
      c1.holdings.create(holding1)
      c2.holdings.create(holding2)
      expect(merged_cluster.holdings.count).to eq(2)
    end

    it "combines OCN resolution rules" do
      c1.ocns = [ocn1, ocn3]
      c1.ocn_resolutions.create(ocn_resolution1)
      c1.save

      c2.ocns = [ocn2, ocn4]
      c2.ocn_resolutions.create(ocn_resolution2)
      c2.save

      expect(merged_cluster.ocn_resolutions.count).to eq(2)
    end

    it "adds OCNs that were in neither cluster" do
      c1
      c2
      expect(described_class.new([ocn1, ocn2, ocn3]).get.ocns)
        .to contain_exactly(ocn1, ocn2, ocn3)
    end

    it "combines ht_items" do
      c1.ht_items.create(htitem1)
      c2.ht_items.create(htitem2)
      expect(merged_cluster.ht_items.count).to eq(2)
    end
  end

  xcontext "when merging >2 clusters" do
    let(:c1) { create(:cluster, ocns: [ocn1]) }
    let(:c2) { create(:cluster, ocns: [ocn2]) }
    let(:c3) { create(:cluster, ocns: [ocn3]) }

    it "combines multiple clusters" do
      c1
      c2
      c3
      expect(Cluster.count).to eq(3)
      expect(described_class.new([ocn1, ocn2, ocn3]).get.ocns).to eq([ocn1, ocn2, ocn3])
      expect(Cluster.count).to eq(1)
    end
  end
end
