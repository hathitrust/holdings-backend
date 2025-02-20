# frozen_string_literal: true

require "spec_helper"
require "cluster"

class Synchronizer
  attr_reader :logger

  def initialize(logger: Services.logger)
    # useful for debugging these tests..
    #  def initialize(logger: Logger.new($stdout, level: Logger::DEBUG))
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

class ClusterInstrumentation
  attr_reader :id, :syncer
  attr_accessor :retry_count, :retry_err

  def initialize(id:, synchronizer:, wait_for:)
    @id = id
    @syncer = synchronizer
    @wait_for = wait_for
  end

  def wait_for(method)
    @syncer.wait_for(@wait_for[method]) if @wait_for[method]
  end

  def write_status(method)
    @syncer.write_status(@id, method)
  end
end

# Uses the synchronizer to record the given ID and the method run
# for find, create, add_additional_ocns, and merge.
#
# Use the "wait_for" array to instruct this instance to wait
# for another instance to run the given method before proceeding, for example:
#
# wait_for: { create: "thread1:array_for_ocns" }
#
# means that this instance should wait for the instance with id thread1 to
# complete the 'find' operation' before this instance does the 'create'
# operation.

class InstrumentedCluster < Cluster
  class << self
    private

    def instrumentation
      Thread.current[:instrumentation]
    end

    [:array_for_ocns, :create, :update_cluster_ocns].each do |method|
      define_method(method) do |*args, **kwargs|
        instrumentation.wait_for(method)
        super(*args, **kwargs).tap do
          instrumentation.write_status(method)
        end
      end
    end

    def transaction_opts
      super.merge(before_retry: ->(num_retries, e) {
        instrumentation.retry_count = num_retries
        instrumentation.retry_err = e
      })
    end
  end
end

RSpec.describe Cluster do
  let(:ocn1) { 5 }
  let(:ocn2) { 6 }
  let(:ht) { build(:ht_item).to_hash }

  include_context "with tables for holdings"

  # import a data structure like
  # {
  #   cluster_id1 => [ ocn1, ocn2, ocn3 ],
  #   cluster_id2 => [ ocn4, ocn5 ]
  #   ...
  # }
  def import_cluster_ocns(cluster_ocns)
    data = []
    cluster_ocns.each do |cluster_id, ocns|
      ocns.each do |ocn|
        data << [cluster_id, ocn]
      end
    end

    db[:cluster_ocns].import([:cluster_id, :ocn], data)
  end

  describe "#initialize" do
    it "creates a new cluster" do
      expect(described_class.new(ocns: [ocn1]).class).to eq(described_class)
    end

    it "has an ocns field that is Set" do
      expect(described_class.new(ocns: [ocn1]).ocns.class).to eq(Set)
    end

    it "has an ocns field with members that are Integers" do
      expect(described_class.new(ocns: [ocn1]).ocns.first.class).to eq(Integer)
    end

    it "can retrieve a cluster's ocns given its id" do
      import_cluster_ocns(
        1 => [1001, 1002, 1003]
      )

      c = Cluster.find(id: 1)
      expect(c.ocns).to contain_exactly(1001, 1002, 1003)
    end

    xit "validates the ocns field is numeric" do
      expect(described_class.new(ocns: ["a"])).not_to be_valid
    end

    xit "validates that it has all HT Item ocns" do
      c = described_class.new(ocns: [ocn1])
      c.save
      c.ht_items.create(ht)
      c.ht_items.first.ocns << rand(1_000_000)
      c.save
      expect(c.errors.messages[:ocns]).to include("must contain all ocns")
    end

    xit "prevents duplicate HT Items" do
      c = described_class.new(ocns: [ocn1])
      c.save
      c.ht_items.create(ht)
      c2 = described_class.new(ocns: [ocn2])
      c2.save
      expect { c2.ht_items.create(ht) }.to \
        raise_error(Mongo::Error::OperationFailure, /ht_items.item_id_1 dup/)
    end
  end

  describe "#for_ocns" do
    it "returns Clusters" do
      import_cluster_ocns(
        1 => [1001],
        2 => [1002]
      )

      clusters = Cluster.for_ocns([1001, 1002])
      expect(clusters).to all(be_a(Cluster))
    end

    it "given one OCN, returns an existing cluster" do
      import_cluster_ocns(
        1 => [1001]
      )

      c = Cluster.for_ocns([1001]).first
      expect(c.id).to eq(1)
    end

    it "given multiple OCNs matching a single cluster, returns it" do
      import_cluster_ocns(
        1 => [1001, 1002, 1003]
      )

      c = Cluster.for_ocns([1001, 1002]).first
      expect(c.id).to eq(1)
    end

    it "given multiple OCNs matching different clusters, returns them" do
      import_cluster_ocns(
        1 => [1001],
        2 => [1002]
      )

      clusters = Cluster.for_ocns([1001, 1002])
      expect(clusters.map(&:id)).to contain_exactly(1, 2)
    end

    it "given multiple OCNs where not all OCNs match a cluster, returns the matching clusters" do
      import_cluster_ocns(
        1 => [1001],
        2 => [1002]
      )

      clusters = Cluster.for_ocns([1001, 1003])
      expect(clusters.map(&:id)).to contain_exactly(1)
    end

    it "given OCNs where no OCN matches a cluster, returns an empty array" do
      import_cluster_ocns(
        1 => [1001],
        2 => [1002]
      )

      clusters = Cluster.for_ocns([9000, 9001])
      expect(clusters.any?).to be(false)
    end
  end

  describe "#ht_items" do
    it "in a cluster with one ocn, returns matching htitem" do
      import_cluster_ocns(
        1 => [1001]
      )

      htitem = build(:ht_item, ocns: [1001])
      insert_htitem(htitem)

      cluster_items = Cluster.find(id: 1).ht_items
      expect(cluster_items.to_a.length).to eq(1)
      expect(cluster_items.first.item_id).to eq(htitem.item_id)
    end

    context "with a cluster with multiple ocns" do
      before(:each) { import_cluster_ocns({1 => [1001, 1002]}) }

      it "returns ht items where some ocns match" do
        htitem = build(:ht_item, ocns: [1001])
        insert_htitem(htitem)

        cluster_items = Cluster.find(id: 1).ht_items
        expect(cluster_items.to_a.length).to eq(1)
        expect(cluster_items.first.item_id).to eq(htitem.item_id)
      end

      it "returns multiple ht items with different ocns" do
        htitem1 = build(:ht_item, ocns: [1001])
        insert_htitem(htitem1)

        htitem2 = build(:ht_item, ocns: [1002])
        insert_htitem(htitem2)

        cluster_items = Cluster.find(id: 1).ht_items
        expect(cluster_items.to_a.length).to eq(2)
        expect(cluster_items.find { |i| i.item_id == htitem1.item_id }).not_to be(nil)
        expect(cluster_items.find { |i| i.item_id == htitem2.item_id }).not_to be(nil)
      end

      it "returns ht items where all ocns match" do
        htitem = build(:ht_item, ocns: [1001, 1002])
        insert_htitem(htitem)

        cluster_items = Cluster.find(id: 1).ht_items
        expect(cluster_items.to_a.length).to eq(1)
        expect(cluster_items.first.item_id).to eq(htitem.item_id)
      end
    end
  end

  describe "#holdings" do
    it "can find a holding in a cluster" do
      import_cluster_ocns(
        1 => [1001]
      )

      holding = create(:holding, ocn: 1001)

      cluster_holdings = Cluster.find(id: 1).holdings
      expect(cluster_holdings.to_a.length).to eq(1)
      expect(cluster_holdings.first.local_id).to eq(holding.local_id)
    end

    it "can find multiple holdings in a cluster with multiple ocns" do
      import_cluster_ocns(
        1 => [1001, 1002]
      )

      holdings = [
        create(:holding, ocn: 1001),
        create(:holding, ocn: 1002)
      ]

      cluster_holdings = Cluster.find(id: 1).holdings
      expect(cluster_holdings.to_a.length).to eq(2)
      expect(cluster_holdings.map(&:local_id)).to contain_exactly(*holdings.map(&:local_id))
    end
  end

  xdescribe "#format" do
    let(:c1) { create(:cluster) }

    it "has a format" do
      formats = ["spm", "mpm", "ser"]
      expect(formats).to include(c1.format)
    end
  end

  xdescribe "#last_modified" do
    let(:c1) { build(:cluster) }

    it "doesn't have last_modified if unsaved" do
      expect(c1.last_modified).to be_nil
    end

    it "has last_modified if it is saved" do
      now = Time.now.utc
      c1.save
      expect(c1.last_modified).to be > now
    end

    it "updates last_modified when it is saved" do
      c1.save
      first_timestamp = c1.last_modified
      c1.save
      second_timestamp = c1.last_modified
      expect(first_timestamp).to be < second_timestamp
    end
  end

  describe "#save" do
    let(:c1) { build(:cluster, ocns: [ocn1, ocn2]) }
    let(:c2) { build(:cluster, ocns: [ocn2]) }

    it "can't save them both" do
      c1.save
      expect { c2.save }.to \
        raise_error(Sequel::UniqueConstraintViolation, /Duplicate entry/)
    end

    it "saves to the database" do
      c1.save
      expect(described_class.count).to eq(1)
      expect(described_class.for_ocns([ocn1]).count).to eq(1)
    end
  end

  xdescribe "Precomputed fields" do
    let(:h1) { build(:holding, ocn: ocn1, enum_chron: "1") }
    let(:h2) { build(:holding, ocn: ocn1, enum_chron: "2", organization: h1.organization) }
    let(:ht1) { build(:ht_item, ocns: [ocn1], enum_chron: "3", billing_entity: h1.organization) }

    before(:each) do
      Clustering::ClusterHolding.new(h1).cluster.tap(&:save)
      Clustering::ClusterHolding.new(h2).cluster.tap(&:save)
      Clustering::ClusterHtItem.new(ht1).cluster.tap(&:save)
      Clustering::ClusterHolding.new(build(:holding, ocn: ocn2, organization: "umich"))
        .cluster.tap(&:save)
      Clustering::ClusterHolding.new(build(:holding, ocn: ocn2, organization: "umich"))
        .cluster.tap(&:save)
      Clustering::ClusterHolding.new(build(:holding, ocn: ocn2, organization: "smu"))
        .cluster.tap(&:save)
    end

    describe "#organizations_in_cluster" do
      it "collects all of the organizations found in the cluster" do
        expect(described_class.first.organizations_in_cluster).to \
          eq([h1.organization, h2.organization, ht1.billing_entity].uniq)
      end
    end

    describe "#item_enums" do
      it "collects all item enums in the cluster" do
        c = described_class.first
        expect(c.item_enums).to eq(["3"])
      end
    end

    describe "#holding_enum_orgs" do
      it "maps enums to member holdings" do
        c = described_class.first
        expect(c.holding_enum_orgs[h1.n_enum]).to eq([h1.organization])
      end
    end

    describe "#org_enums" do
      it "maps orgs to their enums" do
        c = described_class.first
        expect(c.org_enums[h1.organization]).to eq([h1.n_enum, h2.n_enum])
      end
    end

    describe "#organizations_with_holdings_but_no_matches" do
      it "is a list of orgs in the cluster that don't match anything" do
        h3 = build(:holding, ocn: ocn1, enum_chron: "4", organization: "ualberta")
        Clustering::ClusterHolding.new(h3).cluster.tap(&:save)
        c = described_class.first
        expect(c.organizations_with_holdings_but_no_matches).to include("ualberta")
      end

      it "does not include orgs that do have a match" do
        matching_holding = build(:holding, ocn: ocn1, enum_chron: "3")
        Clustering::ClusterHolding.new(matching_holding).cluster.tap(&:save)
        c = described_class.first
        expect(c.organizations_with_holdings_but_no_matches).not_to \
          include(matching_holding.organization)
      end

      it "DOES NOT include orgs that only have a billing entity match" do
        ht2 = build(:ht_item, ocns: [ocn1], enum_chron: "5", billing_entity: "ualberta")
        Clustering::ClusterHtItem.new(ht2).cluster.tap(&:save)
        c = described_class.first
        expect(c.organizations_with_holdings_but_no_matches).not_to include("ualberta")
        # but does if they have a non-matching holding
        h3 = build(:holding, ocn: ocn1, enum_chron: "6", organization: "ualberta")
        Clustering::ClusterHolding.new(h3).cluster.tap(&:save)
        c = described_class.where(ocns: ocn1).first
        expect(c.organizations_with_holdings_but_no_matches).to include("ualberta")
      end
    end

    describe "#holdings_by_org" do
      it "collates holdings by org" do
        c = described_class.where(ocns: ocn2).first
        expect(c.holdings_by_org["umich"].size).to eq(2)
        expect(c.holdings_by_org["smu"].size).to eq(1)
      end
    end

    describe "#copy_counts" do
      it "counts holdings per org" do
        c = described_class.where(ocns: ocn2).first
        expect(c.copy_counts["umich"]).to eq(2)
        expect(c.copy_counts["smu"]).to eq(1)
      end

      xit "cached counts should be invalidated when holdings/ht_items are changed" do
        c = described_class.where(ocns: ocn2).first
        expect(c.copy_counts["umich"]).to eq(2)
        c.holdings.map(&:delete)
        expect(c.holdings.size).to eq(0)
        expect(c.copy_counts["umich"]).to eq(0)
      end
    end
  end

  context "with multiple Clusters doing things in parallel" do
    # useful to have when debugging these specs..
    # let(:syncer) { Synchronizer.new(logger: Logger.new($stdout, level: Logger::DEBUG)) }
    let(:syncer) { Synchronizer.new }

    # We use threading, the Synchronizer, and the InstrumentedCluster to control
    # the sequence of when various things happen across two different transactions
    # to provoke different errors.
    #
    # Each thread has a separate copy of the Cluster class, because we're
    # relying on various class-level methods here. We could consider extracting
    # some of this out to a class if we knew what to call it (not
    # ClusterGetter..)
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
      instrumentation1 = ClusterInstrumentation.new(id: "thread1",
        synchronizer: syncer,
        wait_for: {create: "thread2:array_for_ocns"})

      instrumentation2 = ClusterInstrumentation.new(id: "thread2",
        synchronizer: syncer,
        wait_for: {create: "thread1:create"})

      cluster1 = nil
      cluster2 = nil

      thread1 = Thread.new do
        Thread.current[:instrumentation] = instrumentation1
        cluster1 = InstrumentedCluster.cluster_ocns!([1, 2])
      end

      thread2 = Thread.new do
        Thread.current[:instrumentation] = instrumentation2
        cluster2 = InstrumentedCluster.cluster_ocns!([2])
      end

      [thread1, thread2].each { |t| t.join }
      expect(cluster1.id).to eq(cluster2.id)
      expect(cluster1.ocns).to eq(cluster2.ocns)
      expect(instrumentation2.retry_count).to be > 0
      expect(instrumentation2.retry_err).to be_a(Sequel::UniqueConstraintViolation)
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

      instrumentation1 = ClusterInstrumentation.new(
        id: "thread1", synchronizer: syncer,
        wait_for: {add_additional_ocns: "thread2:array_for_ocns"}
      )

      instrumentation2 = ClusterInstrumentation.new(
        id: "thread2", synchronizer: syncer,
        wait_for: {create: "thread1:update_cluster_ocns"}
      )

      cluster1 = nil
      cluster2 = nil

      thread1 = Thread.new do
        Thread.current[:instrumentation] = instrumentation1
        cluster1 = InstrumentedCluster.cluster_ocns!([1, 2])
      end

      thread2 = Thread.new do
        Thread.current[:instrumentation] = instrumentation2
        cluster2 = InstrumentedCluster.cluster_ocns!([2])
      end

      [thread1, thread2].each { |t| t.join }
      expect(cluster1.id).to eq(cluster2.id)
      expect(cluster1.ocns).to eq(cluster2.ocns)
      expect(instrumentation2.retry_count).to be > 0
      expect(instrumentation2.retry_err).to be_a(Sequel::UniqueConstraintViolation)
    end

    # case 3:
    # cluster [1] exists
    # thread1: [1,2]; thread2: [2]
    # thread1 find -- gets [1]
    # thread2 find -- gets nothing
    # thread2 create - makes [2]
    # thread1 add_ocns - gets duplicate key error, should retry & merge
    # thread2 has an outdated cluster id & list of OCNs... but that's probably OK (see below)
    it "when one transaction tries to create a cluster with two OCNs and another tries to make a cluster with one of those OCNs, retries and merges" do
      create(:cluster, ocns: [1])
      cluster1 = nil
      cluster2 = nil

      instrumentation1 = ClusterInstrumentation.new(
        id: "thread1", synchronizer: syncer,
        wait_for: {update_cluster_ocns: "thread2:create"}
      )

      instrumentation2 = ClusterInstrumentation.new(
        id: "thread2", synchronizer: syncer,
        wait_for: {create: "thread1:array_for_ocns"}
      )

      thread1 = Thread.new do
        Thread.current[:instrumentation] = instrumentation1
        cluster1 = InstrumentedCluster.cluster_ocns!([1, 2])
      end

      thread2 = Thread.new do
        Thread.current[:instrumentation] = instrumentation2
        cluster2 = InstrumentedCluster.cluster_ocns!([2])
      end

      [thread1, thread2].each { |t| t.join }

      expect(Cluster.first.ocns).to contain_exactly(1, 2)
      expect(Cluster.count).to eq(1)
      expect(instrumentation1.retry_count).to be > 0
      expect(instrumentation1.retry_err).to be_a(Sequel::UniqueConstraintViolation)
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

      instrumentation1 = ClusterInstrumentation.new(
        id: "thread1", synchronizer: syncer,
        wait_for: {create: "thread2:array_for_ocns"}
      )

      instrumentation2 = ClusterInstrumentation.new(
        id: "thread2", synchronizer: syncer,
        wait_for: {create: "thread1:create"}
      )

      thread1 = Thread.new do
        Thread.current[:instrumentation] = instrumentation1
        cluster1 = InstrumentedCluster.cluster_ocns!([1])
      end

      thread2 = Thread.new do
        Thread.current[:instrumentation] = instrumentation2
        cluster2 = InstrumentedCluster.cluster_ocns!([1, 2])
      end

      [thread1, thread2].each { |t| t.join }

      expect(Cluster.first.ocns).to contain_exactly(1, 2)
      expect(Cluster.count).to eq(1)

      expect(cluster1.id).to eq(cluster2.id)
      expect(instrumentation2.retry_count).to be > 0
      expect(instrumentation2.retry_err).to be_a(Sequel::UniqueConstraintViolation)
    end

    # Case 3 and 4 demonstrate that we shouldn't use the returned cluster ID or
    # list of OCNs from Cluster to *do* anything. The purpose of
    # Cluster is really just to make it so that the given OCNs are in the
    # *same cluster*. We should never call Cluster.get in a situation
    # where we're only *reading* data as Cluster.get will *modify* the
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
    # from Cluster.get to do anything (again a reason for renaming this)
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

  context "when merging two clusters" do
    let(:merged_cluster) { Cluster.cluster_ocns!([5, 6]) }

    it "combines ocns sets" do
      create(:cluster, ocns: [5])
      create(:cluster, ocns: [6])

      expect(merged_cluster.ocns).to contain_exactly(5, 6)
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ocns).to contain_exactly(5, 6)
    end

    it "gets holdings from merged OCNs" do
      create(:cluster, ocns: [5])
      create(:cluster, ocns: [6])
      create(:holding, ocn: 5)
      create(:holding, ocn: 6)

      expect(merged_cluster.holdings.count).to eq(2)
    end

    it "gets OCN resolution rules for merged OCNs" do
      create(:cluster, ocns: [5, 7])
      create(:cluster, ocns: [6, 8])
      create(:ocn_resolution, canonical: 5, variant: 7)
      create(:ocn_resolution, canonical: 6, variant: 8)

      expect(merged_cluster.ocn_resolutions.count).to eq(2)
    end

    it "adds OCNs that were in neither cluster" do
      create(:cluster, ocns: [5])
      create(:cluster, ocns: [6])

      expect(Cluster.cluster_ocns!([5, 6, 7]).ocns)
        .to contain_exactly(5, 6, 7)

      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ocns).to contain_exactly(5, 6, 7)
    end

    it "combines ht_items" do
      create(:cluster, ocns: [5])
      create(:cluster, ocns: [6])
      insert_htitem(build(:ht_item, ocns: [5]))
      insert_htitem(build(:ht_item, ocns: [6]))

      expect(merged_cluster.ht_items.count).to eq(2)
    end
  end

  context "when merging >2 clusters" do
    it "combines multiple clusters" do
      create(:cluster, ocns: [5])
      create(:cluster, ocns: [6])
      create(:cluster, ocns: [7])

      expect(Cluster.count).to eq(3)
      expect(Cluster.cluster_ocns!([5, 6, 7]).ocns).to contain_exactly(5, 6, 7)
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ocns).to contain_exactly(5, 6, 7)
    end
  end
end
