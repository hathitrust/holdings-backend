# frozen_string_literal: true

require "cluster"
require "services"
Services.mongo!

module Reports
  # Finds clusters matching the criteria:
  # has holdings,
  # has no (active) commitments,
  # has items with access:allow,
  # has format: spm,
  # has up to a specified no. of members holding it.
  # The number of members can be counted as regular members, shared print members,
  # or both (set independently).
  # Usage:
  #
  # Find clusters held by up to 5 members:
  # clusters = Reports::RareUncommitted.new.run(h: 5).to_a
  #
  # Find clusters held by up to 2 sp members:
  # clusters = Reports::RareUncommitted.new.run(sph: 2).to_a
  #
  # Find clusters held by up to 5 members and up to 2 sp members:
  # clusters = Reports::RareUncommitted.new.run(h: 5, sph: 2).to_a
  class RareUncommitted
    def initialize(memoize_orgs: true)
      @memoize_orgs = memoize_orgs # memoize sp_organizations if true, turn off for testing
      @query = {
        "ht_items.0" => {"$exists": 1},
        "holdings.0" => {"$exists": 1}
      }
    end

    # All organizations that participate in the HT SP program.
    def sp_organizations
      if @memoize_orgs
        @sp_organizations ||= Cluster.distinct("commitments.organization").compact
      else
        # For testing.
        Cluster.distinct("commitments.organization").compact
      end
    end

    # Returns the clusters matching the query & h/sph criteria.
    # h   = no of distinct    orgs with holdings on a cluster
    # sph = no of distinct sp orgs with holdings on a cluster
    # Args use nil to mean undefined because 0 is a meaningful number in this context.
    def run(sph: nil, h: nil)
      return enum_for(:run, sph: sph, h: h) unless block_given?

      if sph.nil? && h.nil?
        raise ArgumentError,
          "Both args sph and h are nil. At least one of them must be not-nil."
      end

      Services.logger.debug "run(sph: #{sph}, h: #{h})"
      Cluster.where(@query).no_timeout.each do |cluster|
        Services.logger.debug "check cluster #{cluster.ocns}"
        # Try to reject the cluster, based on various things:
        next if reject_based_on_format?(cluster)
        next if reject_based_on_access?(cluster)
        next if reject_based_on_commitments?(cluster)
        next if reject_based_on_sph?(cluster, sph)
        next if reject_based_on_h?(cluster, h)
        # If we didn't find reason to reject cluster, then the cluster goes in the report.
        Services.logger.debug "yield cluster #{cluster.ocns}"
        yield cluster
      end
    end

    # Runs the report and condenses it down to counts.
    def counts(sph: nil, h: nil)
      clusters = run(sph: sph, h: h).to_a

      counts_data = {
        h: {},
        sph: {}
      }

      # Populate counts for each sph [0 .. sph]
      unless sph.nil?
        0.upto(sph).each do |i|
          counts_data[:sph][i] = {
            total_items: 0,
            num_clusters: 0
          }
        end
        clusters.each do |cluster|
          sph = cluster_sph(cluster)
          total_items = cluster.ht_items.count
          counts_data[:sph][sph][:total_items] += total_items
          counts_data[:sph][sph][:num_clusters] += 1
        end
      end

      # Same for h
      unless h.nil?
        0.upto(h).each do |i|
          counts_data[:h][i] = {
            total_items: 0,
            num_clusters: 0
          }
        end
        clusters.each do |cluster|
          h = cluster_h(cluster)
          total_items = cluster.ht_items.count
          counts_data[:h][h][:total_items] += total_items
          counts_data[:h][h][:num_clusters] += 1
        end
      end

      counts_data
    end

    # Calls counts and returns the formatted report as a string.
    def counts_format(h: nil, sph: nil)
      buf = []
      counts = counts(h: h, sph: sph)
      header = [
        "number of holding libraries",
        "type of member holding",
        "total_items",
        "num_clusters"
      ]
      buf << header.join("\t")

      counts.keys.each do |h_type|
        counts[h_type].keys.each do |h_val|
          data = counts[h_type][h_val]
          buf << [
            h_val,
            type_map[h_type],
            data[:total_items],
            data[:num_clusters]
          ].join("\t")
        end
      end

      buf.join("\n")
    end

    private

    def type_map
      {sph: "retention library", h: "member library"}
    end

    # Given the format of the cluster, should it be rejected from the report?
    def reject_based_on_format?(cluster)
      Services.logger.debug "check cluster format (#{cluster.format})"
      if cluster.format == "spm"
        Services.logger.debug "allow"
        false
      else
        Services.logger.debug "reject"
        true
      end
    end

    # Given the access value on the cluster, should it be rejected from the report?
    def reject_based_on_access?(cluster)
      Services.logger.debug "check cluster access"
      if cluster.ht_items.collect(&:access).include? "allow"
        Services.logger.debug "allow"
        false
      else
        Services.logger.debug "reject"
        true
      end
    end

    # Given cluster_sph and sph, should this cluster be rejected from the report?
    def reject_based_on_sph?(cluster, sph)
      return false if sph.nil?

      Services.logger.debug "check cluster_sph (#{cluster_sph(cluster)}) > sph (#{sph})"
      if cluster_sph(cluster) > sph
        Services.logger.debug "reject"
        true
      else
        Services.logger.debug "allow"
        false
      end
    end

    # Which/how many sp members have holdings in this cluster?
    def cluster_sph(cluster)
      holding_sp_orgs = cluster.holdings.collect(&:organization).uniq & sp_organizations
      holding_sp_orgs.size
    end

    # Given cluster_h and h, should the cluster be rejected from the report?
    def reject_based_on_h?(cluster, h)
      return false if h.nil?

      Services.logger.debug "check cluster_h (#{cluster_h(cluster)} > #{h})"
      if cluster_h(cluster) > h
        Services.logger.debug "reject"
        true
      else
        Services.logger.debug "allow"
        false
      end
    end

    # How many members have reported holdings on the cluster?
    def cluster_h(cluster)
      holding_orgs = cluster.holdings.collect(&:organization).uniq
      holding_orgs.size
    end

    # Given the commitments on the cluster, should the cluster be rejected from the report?
    def reject_based_on_commitments?(cluster)
      Services.logger.debug "check cluster #{cluster.ocns}: commitments?"
      if cluster.commitments.reject(&:deprecated?).any?
        Services.logger.debug "reject"
        true
      else
        Services.logger.debug "allow"
        false
      end
    end
  end
end
