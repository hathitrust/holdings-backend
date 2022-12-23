# frozen_string_literal: true

require "cluster"
require "services"
require "shared_print/groups"
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
  # clusters = Reports::RareUncommitted.new(max_h: 5).clusters.to_a
  #
  # Find clusters held by up to 2 sp members:
  # clusters = Reports::RareUncommitted.new(max_sp_h: 2).clusters.to_a
  #
  # Find clusters held by up to 5 members and up to 2 sp members:
  # clusters = Reports::RareUncommitted.new(max_h: 5, max_sp_h: 2).clusters.to_a
  class RareUncommitted
    def initialize(
      max_h: nil,
      max_sp_h: nil,
      non_sp_h_count: nil,
      commitment_count: 0,
      organization: nil,
      memoize_orgs: true
    )
      if [max_h, max_sp_h, non_sp_h_count].compact.empty?
        raise ArgumentError,
          "max_h, max_sp_h & non_sp_h_count are nil. At least one of them must not be."
      end

      # A selected cluster should have h <= @max_h, if set
      @max_h = max_h
      # A selected cluster should have max_sp_h <= @max_sp_h, if set
      @max_sp_h = max_sp_h
      # A selected cluster should have non_sp_h_count <= @non_sp_h_count, if set
      @non_sp_h_count = non_sp_h_count
      # A selected cluster should have commitment_count == @commitment_count, default 0
      @commitment_count = commitment_count
      # If given an organization, do record output for that organization
      @organization = organization
      @sp_groups = SharedPrint::Groups.new

      # A selected cluster should always have at least items and holdings.
      @query = {
        "ht_items.0" => {"$exists": 1},
        "holdings.0" => {"$exists": 1}
      }

      unless @organization.nil?
        @query["holdings.organization"] = @organization
      end

      # memoize organization lookups if true, turn off for testing
      @memoize_orgs = memoize_orgs
    end

    # Calls counts and yields the formatted report one line at a time.
    def output_counts
      return enum_for(:output_counts) unless block_given?

      counts_data = counts
      log counts_data.inspect
      header = [
        "number of holding libraries",
        "type of member holding",
        "total_items",
        "num_clusters"
      ].join("\t")
      yield header

      counts_data.keys.each do |h_type|
        counts_data[h_type].keys.each do |h_val|
          data = counts_data[h_type][h_val]
          output = [
            h_val,
            type_map[h_type],
            data[:total_items],
            data[:num_clusters]
          ].join("\t")

          yield output
        end
      end
    end

    # Runs the report and condenses it down to counts.
    def counts
      results = clusters.to_a

      {
        h: populate_counts(results, @max_h, :h),
        sp_h: populate_counts(results, @max_sp_h, :sp_h),
        non_sp_h: populate_counts(results, @non_sp_h_count, :non_sp_h)
      }
    end

    # Runs the report and outputs all matching records
    def output_organization
      return enum_for(:output_organization) unless block_given?

      header = [
        "member_id",
        "local_id",
        "gov_doc",
        "condition",
        "OCN",
        "overlap_ht",
        "overlap_sp"
      ]
      # If @organization is in any @sp_groups then we need to track that.
      header << "overlap_group" if in_group.any?
      yield header.join("\t")

      clusters do |cluster|
        cluster.holdings.each do |holding|
          if !@organization.nil?
            next unless holding.organization == @organization
          end

          # We store gov_doc_flag as a true/false and the report wants 1/0.
          govdoc_bool_2_int = holding.gov_doc_flag == true ? 1 : 0

          record = [
            holding.organization,
            holding.local_id,
            govdoc_bool_2_int,
            holding.condition,
            holding.ocn,
            cluster_h(cluster),
            cluster_sp_h(cluster)
          ]
          record << group_overlap(cluster) if in_group.any?
          yield record.join("\t")
        end
      end
    end

    def run(output_filename = report_file)
      report_data = @organization.nil? ?
                      output_counts : output_organization

      File.open(output_filename, "w") do |fh|
        report_data.each do |report_line|
          fh.puts report_line
        end
      end
    end

    # Returns the clusters matching the query & holdings/commitments criteria.
    def clusters
      return enum_for(:clusters) unless block_given?

      marker = Services.progress_tracker.new(1000)
      Cluster.where(@query).no_timeout.each do |cluster|
        marker.incr
        marker.on_batch { |m| Services.logger.info m.batch_line }
        log "--- check cluster #{cluster.ocns} ---"
        # Try to reject the cluster, based on various things:
        next if reject_based_on_format?(cluster)
        next if reject_based_on_access?(cluster)
        next if reject_based_on_commitments?(cluster)
        next if reject_based_on_h?(cluster)
        next if reject_based_on_sp_h?(cluster)
        next if reject_based_on_non_sp_h?(cluster)

        # If we didn't find reason to reject cluster, then the cluster goes in the report.
        log "yield cluster #{cluster.ocns}"
        yield cluster
      end
      Services.logger.info marker.final_line
    end

    # All orgs that have holdings.
    def all_organizations
      if @memoize_orgs
        @all_organizations ||= Cluster.distinct("holdings.organization").compact
      else
        # For testing.
        Cluster.distinct("holdings.organization").compact
      end
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

    # All orgs that have holdings but not commitments.
    def non_sp_organizations
      # Don't care to check @memoize_orgs here, the other methods do it.
      all_organizations - sp_organizations
    end

    # The groups that @organization is a member of, if any
    def in_group
      @in_group ||= (@sp_groups.org_to_groups(@organization) || [])
    end

    # The other orgs in the groups that @organization is member of, if any
    def other_orgs_in_group
      if @other_orgs_in_group.nil? && in_group.any?
        @other_orgs_in_group = []
        in_group.each do |group|
          @other_orgs_in_group << @sp_groups
            .group_to_orgs(group)
            .reject { |org| org == @organization }
        end
        @other_orgs_in_group.flatten!
      end
      @other_orgs_in_group
    end

    # Populate one section (based on h_type) of the counts structure
    def populate_counts(clusters, counter, h_type)
      h_type_counts = {}
      unless counter.nil?
        start_count = 0
        # For :non_sp_h we only care about exact matches, not the range up to.
        if h_type == :non_sp_h
          start_count = @non_sp_h_count
        end
        start_count.upto(counter).each do |h_val|
          h_type_counts[h_val] = {
            total_items: 0,
            num_clusters: 0
          }
        end
        clusters.each do |cluster|
          h_val = counts_for_h_type(cluster, h_type) # e.g. is this a sp_h:5 cluster?
          total_items = cluster.ht_items.count
          h_type_counts[h_val][:total_items] += total_items
          h_type_counts[h_val][:num_clusters] += 1
        end
      end

      h_type_counts
    end

    # dry-method for output_counts
    def counts_for_h_type(cluster, h_type)
      case h_type
      when :h
        cluster_h(cluster)
      when :sp_h
        cluster_sp_h(cluster)
      when :non_sp_h
        cluster_non_sp_h(cluster)
      end
    end

    def log(msg)
      Services.logger.debug msg
    end

    # For output formatting
    def type_map
      {
        h: "member library",
        sp_h: "retention library",
        non_sp_h: "non-retention member library"
      }
    end

    # Given the format of the cluster, should it be rejected from the report?
    def reject_based_on_format?(cluster)
      log "check format (#{cluster.format})"
      reject_if_true(cluster.format != "spm")
    end

    # Given the access value on the cluster, should it be rejected from the report?
    def reject_based_on_access?(cluster)
      cluster_access = cluster.ht_items.collect(&:access).uniq
      log "check access (#{cluster_access.join(",")})"
      reject_if_true(!cluster_access.include?("allow"))
    end

    # Given cluster_h and @max_h, should the cluster be rejected from the report?
    def reject_based_on_h?(cluster)
      return false if @max_h.nil?

      cluster_count_val = cluster_h(cluster)
      log "check_h (#{cluster_count_val} > #{@max_h}) ?"
      reject_if_true(cluster_count_val > @max_h)
    end

    # Given cluster_sp_h and @max_sp_h, should this cluster be rejected from the report?
    def reject_based_on_sp_h?(cluster)
      return false if @max_sp_h.nil?

      cluster_count_val = cluster_sp_h(cluster)
      log "check cluster_sp_h (#{cluster_count_val}) > sp_h (#{@max_sp_h}) ?"
      reject_if_true(cluster_count_val > @max_sp_h)
    end

    # Given cluster_sp_h and @max_sp_h, should this cluster be rejected from the report?
    def reject_based_on_non_sp_h?(cluster)
      return false if @non_sp_h_count.nil?

      cluster_count_val = cluster_non_sp_h(cluster)
      log "check cluster_non_sp_h (#{cluster_count_val}) == non_sp_h_count (#{@non_sp_h_count}) ?"
      reject_if_true(cluster_count_val != @non_sp_h_count)
    end

    # Given the commitments on the cluster and @commitment_count,
    # should the cluster be rejected from the report?
    def reject_based_on_commitments?(cluster)
      # The number of non-deprecated commitments must match @commitment_count
      active = cluster.commitments.reject(&:deprecated?)
      log "check commitments #{active.size} == #{@commitment_count}?"
      reject_if_true(active.size != @commitment_count)
    end

    # DRY for the return of the "reject_if_x" methods
    def reject_if_true(expr)
      if expr
        log "reject"
        true
      else
        log "allow"
        false
      end
    end

    # How many members have reported holdings on the cluster?
    def cluster_h(cluster)
      holding_orgs = cluster.holdings.collect(&:organization).uniq
      holding_orgs.size
    end

    # How many sp members have holdings in this cluster?
    def cluster_sp_h(cluster)
      holding_sp_orgs = cluster.holdings.collect(&:organization).uniq & sp_organizations
      holding_sp_orgs.size
    end

    # How many non-sp members have holdings in this cluster?
    def cluster_non_sp_h(cluster)
      holding_non_sp_orgs = cluster.holdings.collect(&:organization).uniq & non_sp_organizations
      holding_non_sp_orgs.size
    end

    # counts how many other organizations that are part of the same “group“
    # have holdings in the same cluster.
    def group_overlap(cluster)
      group_overlap_orgs = cluster.holdings.collect(&:organization).uniq & other_orgs_in_group
      group_overlap_orgs.size
    end

    private

    def report_file
      FileUtils.mkdir_p(Settings.shared_print_report_path)
      iso_stamp = Time.now.strftime("%Y%m%d-%H%M%S")
      rand_str = SecureRandom.hex(8)
      tag = "counts"
      tag = @organization if @organization
      File.join(Settings.shared_print_report_path, "rare_uncommitted_#{tag}_#{iso_stamp}_#{rand_str}.txt")
    end
  end
end
