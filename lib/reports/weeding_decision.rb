# frozen_string_literal: true

require "cluster"
require "services"
Services.mongo!

# This is a Shared Print report from the point of view of a SP member
# who wants to know which titles in their collection seem "safe" to weed.
# We look at all of their commitments and give some info incl how many
# other members have commitments on the same title.

module Reports
  class WeedingDecision
    def initialize(organization)
      @organization = organization
    end

    # Writes full report to outfile location.
    def run
      File.open(outf, "w") do |f|
        f.puts header # writes report header line
        body do |rec| # writes report body lines
          f.puts rec
        end
      end
    end

    # Specifies outfile location.
    def outf
      dir = [Settings.weeding_decision_report_pat, "/tmp"].compact.first
      ymd = Time.now.strftime("%Y-%m-%d")
      filename = "weeding_decision_#{@organization}_#{ymd}.tsv"
      File.join(dir, filename)
    end

    # Returns report header line.
    def header
      [
        "ocn",
        "local_id",
        "open_items",
        "closed_items",
        "local_copies",
        "num_orgs_holding",
        "local_commitments",
        "all_commitments"
      ].join("\t")
    end

    # Run query and yield output records. Most of the heay lifting happens here.
    def body
      return enum_for(:body) unless block_given?
      Cluster.where(query).no_timeout.each do |cluster|
        # The query reqs that clusters have holdings, items and commitments,
        # so we don't need to nil-check them.
        # Check that there are *active* commitments, skip cluster if not.
        active_commitments = cluster.commitments.select { |c| c.deprecated? == false }
        next if active_commitments.empty?

        # A hash based on zero_access, with at least one non-zero value.
        # Skip cluster if there are no open items.
        access_tally = zero_access.merge(cluster.ht_items.map(&:access).tally)
        next if access_tally["allow"].zero?

        # All the holdings in the cluster held by @organization:
        org_holdings = cluster.holdings.select { |h| h.organization == @organization }

        # Number of organizations with holdings:
        num_orgs_holding = cluster.holdings.map { |h| h.organization }.uniq.count

        # Hash of commitments per committer in this cluster.
        commitments_tally = active_commitments.map(&:organization).tally

        # Dedupe local holdings for output.
        hol_groups = org_holdings.group_by { |h| [h.ocn, h.local_id] }
        hol_groups.keys.each do |ocn, local_id|
          yield WeedingRecord.new(
            ocn,
            local_id,
            access_tally["allow"],
            access_tally["deny"],
            org_holdings.count,
            num_orgs_holding,
            commitments_tally[@organization] || 0,
            commitments_tally
          )
        end
      end
    end

    private

    # Mongo query for the matching records.
    def query
      {
        "holdings.organization": @organization,
        "commitments.0": {"$exists": 1},
        "ht_items.0": {"$exists": 1}
      }
    end

    # Template for ht_items access tally.
    def zero_access
      {
        "allow" => 0,
        "deny" => 0
      }
    end
  end

  # Represents one line in the output WeedingDecision report.
  # Just a neat wrapper, does almost no work.
  class WeedingRecord
    attr_reader :ocn, :local_id, :open_items, :closed_items, :local_copies, :num_orgs_holding, :local_commitments, :commitments_tally
    def initialize(ocn, local_id, open_items, closed_items, local_copies, num_orgs_holding, local_commitments, commitments_tally)
      @ocn = ocn
      @local_id = local_id
      @open_items = open_items
      @closed_items = closed_items
      @local_copies = local_copies
      @num_orgs_holding = num_orgs_holding
      @local_commitments = local_commitments
      @commitments_tally = commitments_tally
    end

    def to_s
      [
        @ocn,
        @local_id,
        @open_items,
        @closed_items,
        @local_copies,
        @num_orgs_holding,
        @local_commitments,
        # Make it slightly more human readable for the report:
        @commitments_tally.map { |k, v| "#{k}:#{v}" }.join(", ")
      ].join("\t")
    end
  end
end
