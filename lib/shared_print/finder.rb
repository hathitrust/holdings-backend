# frozen_string_literal: true

require "cluster"
require "services"
require "shared_print/phases"

Services.mongo!

module SharedPrint
  # Pass criteria to new(), and
  # * call clusters()    to yield the matching clusters,
  # * call commitments() to yield the matching commitments.
  class Finder
    attr_reader :organization, :ocn, :local_id, :deprecated, :phase, :query
    def initialize(organization: [], ocn: [], local_id: [], deprecated: false, phase: [])
      @organization = organization
      @ocn = ocn
      @local_id = local_id
      @deprecated = deprecated # nil = don't care, could be deprecated or not.
      @phase = phase
      # Put together a query based on the criteria gathered.
      @query = build_query
    end

    # Yield matching clusters.
    def clusters
      return enum_for(:clusters) unless block_given?

      Cluster.where(@query).no_timeout.each do |cluster|
        yield cluster
      end
    end

    # Yield matching commitments in matching clusters.
    def commitments
      return enum_for(:commitments) unless block_given?

      clusters do |cluster|
        cluster.commitments.each do |commitment|
          yield commitment if match?(commitment)
        end
      end
    end

    private

    # Build a hash that can be used as arg to Cluster.where().
    # This query returns whole clusters.
    def build_query
      q = {"commitments.0": {"$exists": 1}}
      if @organization.any?
        q["commitments.organization"] = {"$in": @organization}
      end
      if @ocn.any?
        q["commitments.ocn"] = {"$in": @ocn}
      end
      if @local_id.any?
        q["commitments.local_id"] = {"$in": @local_id}
      end
      if @phase.any?
        q["commitments.committed_date"] = {"$in": phase_to_date}
      end

      q
    end

    # The Cluster.where() query returns whole clusters,
    # so we can iterate over the commitments of those clusters
    # and return only the commitments that match.
    def match?(commitment)
      (@deprecated.nil? || @deprecated == commitment.deprecated?) &&
        empty_or_include?(@organization, commitment.organization) &&
        empty_or_include?(@ocn, commitment.ocn) &&
        empty_or_include?(@local_id, commitment.local_id)
    end

    # A commitment matches e.g. the @ocn acriterion if @ocn == []
    # or if @ocn contains commitment.ocn.
    def empty_or_include?(arr, val)
      arr.empty? || arr.include?(val)
    end

    def phase_to_date(phase = @phase)
      # In shared print, we've accepted commitments in phases, with slightly different
      # criteria. E.g. policies and condition were added as required fields for phase
      # 3. Phases are associated with the date they were committed. So this is a map
      # from phase to date, so we can find the commitments for a certain phase.
      phase_hash = SharedPrint::Phases.phase_to_date
      phase.uniq.map do |p|
        if phase_hash.key?(p)
          phase_hash[p]
        else
          raise ArgumentError, "Phase #{p} is not a recognized shared print phase"
        end
      end
    end
  end
end
