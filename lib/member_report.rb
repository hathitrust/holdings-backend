# frozen_string_literal: true

require 'cluster'
require 'calculate_format'

# Get data from mongo to provide reports on members' holdings as they relate
# to format, overlap with ht items, etc.
#
#
# number of reported print holdings for a given member, grouped by format (spm, ser, mpm)
# number of holdings from a member that match volumes in HT, grouped by format (spm, ser, mpm)
# number of distinct ocns (~titles) a given member holds grouped by format (spm, ser, mpm)
# number of volumes in HT that match a given member's holdings, grouped by access (allow/deny) and format (spm, ser, mpm)
# number of distinct ocns (~titles) in a member's holdings matching items in HT grouped by format (spm, ser, mpm)

class MemberReport
  class AllowDenyCounts
    attr_accessor :allow, :deny

    def initialize
      @allow = 0
      @deny  = 0
    end
  end

  class MatchingCounts
    attr_accessor :held, :all

    def initialize
      @held = 0
      @all  = 0
    end

    def total
      @all
    end
  end

  # spm => {match => {allow:, deny:}, {all => {allow:, deny:}}, ...
  class AccessMatchingCounts
    def initialize
      @held = AllowDenyCounts.new
      @all  = AllowDenyCounts.new
    end

    def total
      @all.allow + @all.deny
    end
  end

  # A wrapper of sorts to derive what we need from a cluster
  class ClusterReportData

    def initialize(institution:, cluster:)
      @cluster     = cluster
      @institution = institution
    end

    def total
      @counts.values.map(&:total).sum
    end

    def format
      @cluster.format
    end

    def holdings
      @holdings ||= @cluster.holdings.select { |h| h.organization == @institution }
    end

  end

  # Currently, only support a single institution (assuming on-demand creation of reports).
  # If multiple reports are needed, there's so much overlap work (in terms of getting an
  # analyzing all the clusters) that it'd be worth it to allow multiple institutions
  # via Cluster.where("holdings.organization" => {'$in' => [inst1, inst2, ...]})

  include Enumerable

  attr_accessor :selector, :institution

  def initialize(institution:)
    @institution = institution
    @selector    = Cluster.where("holdings.organization" => institution)
  end

  def counts_structure
    {
      "mpm"     => { clusters: 0, holdings: 0 },
      "ser/spm" => { clusters: 0, holdings: 0 },
      "ser"     => { clusters: 0, holdings: 0 },
      "spm"     => { clusters: 0, holdings: 0 }
    }
  end

  def matching_counts_structure
    {
      "mpm"     => MatchingCounts.new,
      "ser/spm" => MatchingCounts.new,
      "ser"     => MatchingCounts.new,
      "spm"     => MatchingCounts.new
    }
  end

  def access_matching_counts_structure
    {
      "mpm"     => AccessMatchingCounts.new,
      "ser/spm" => AccessMatchingCounts.new,
      "ser"     => AccessMatchingCounts.new,
      "spm"     => AccessMatchingCounts.new
    }
  end

  # wrap clusters in clusterReportData classes for convenience
  def each
    selector.each do |cluster|
      yield ClusterReportData.new(cluster: cluster, institution: institution)
    end
  end

  # number of reported print holdings for a given member, grouped by format (spm, ser, mpm)
  # This should get folded into a method that computes all the data once, presuming that
  # each of these "reports" (just one or a few lines) will be computed at once
  def holdings_and_clusters_by_format
    @holdings_and_clusters_by_format ||=
      self.each_with_object(counts_structure) do |crd, counts|
        counts[crd.format][:clusters] += 1
        counts[crd.format][:holdings] += crd.holdings.size
      end
  end

  def holdings_by_format
    holdings_and_clusters_by_format.each_with_object({}) do |kv, h|
      format, counts = *kv
      h[format]      = counts[:holdings]
    end
  end

  # number of distinct ocns (~titles) a given member holds grouped by format (spm, ser, mpm)
  def titles_by_format
    holdings_and_clusters_by_format.each_with_object({}) do |kv, h|
      format, counts = *kv
      h[format]      = counts[:clusters]
    end
  end

end

# Example of a aggregation pipeline query that gets data by the _reported_ type of holding
# (as opposed to the computed version from )
# bu_only.collection.aggregate(
#   [
#     { '$unwind': '$holdings' },2
#     { '$match': {'holdings.organization': 'bu'}},
#     { '$group': {
#         _id:   {
#           organization: '$holdings.organization',
#           item_type:    '$holdings.mono_multi_serial'
#         },
#         count: {
#         '$sum': 1
#         }
#     }},
#     {
#         '$project' =>  {
#           _id: 0,
#           organization: "$_id.organization",
#           type: "$_id.item_type",
#           count: 1
#         }
#     },
#     { '$sort' => { '_id.organization' => 1 } },
#   ]
# )