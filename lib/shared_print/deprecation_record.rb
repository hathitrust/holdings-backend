# frozen_string_literal: true

module SharedPrint
  # Represents a line in a file of (shared print) deprecation requests,
  # and can try to find a Commitment that matches it.
  class DeprecationRecord
    attr_reader :organization, :ocn, :local_id, :status, :err

    def initialize(organization: nil, ocn: nil, local_id: nil, status: nil)
      @ocn = ocn.to_i
      @organization = organization
      @local_id = local_id
      @status = status
      @allowed_status = ["C", "D", "E", "L", "M"]
      @err = []
      validate!
    end

    def to_s
      [
        "ocn:#{@ocn},",
        "organization:#{@organization},",
        "local_id:#{@local_id},",
        "status:#{@status}"
      ].join(" ")
    end

    def self.parse_line(line)
      cols = line.strip.split("\t")
      new(
        organization: cols[0],
        ocn: cols[1],
        local_id: cols[2],
        status: cols[3]
      )
    end

    # If ocn does not return a cluster, add to @err
    def cluster
      @cluster ||= Cluster.where(ocns: @ocn).first
      if @err.empty? && @cluster.nil?
        @err << "No cluster found for OCN:#{ocn}"
      end

      @cluster
    end

    # If cluster does not have commitments, add to @err
    def commitments
      return @commitments unless @commitments.nil?

      if cluster.nil? || cluster.commitments.empty?
        @err << "No commitments found in cluster"
        @commitments = []
      else
        @commitments = cluster.commitments
      end
      @commitments
    end

    # If cluster does not have commitments by dep.organization, add to @err
    # Return the commitments that _do_ match dep.organization.
    def org_commitments
      return @org_commitments unless @org_commitments.nil?

      if @err.empty?
        @org_commitments = commitments.select do |c|
          c.organization == @organization
        end
        if @org_commitments.empty?
          @err << "No commitments by organization:#{organization} in cluster."
        end
      end
      @org_commitments
    end

    # If commitments contain deprecated ones, add to @err and remove them.
    # Return only non-deprecated
    def reject_deprecated
      already_deprecated = org_commitments.select(&:deprecated?)
      @org_commitments.reject!(&:deprecated?)
      if @err.empty? && org_commitments.empty?
        @err << "Only deprecated commitments found:"
        already_deprecated.each do |already_dep|
          @err << already_dep.inspect
        end
      end
      @org_commitments
    end

    # If no commitment matches local_id, add to @err.
    # Return the one(s) that do(es) match.
    def local_id_matches
      @local_id_matches = org_commitments.select { |c| c.local_id == @local_id }
      if @err.empty? && @local_id_matches.empty?
        @err << "No commitment with local_id:#{@local_id} found"
      end
      @local_id_matches
    end

    # Multiple local_id matches is an error maybe?
    def multiple_matches?
      if @err.empty? && local_id_matches.size > 1
        @err << "Multiple matches found:"
        local_id_matches.each do |match|
          @err << match.inspect
        end
      end
    end

    def find_commitment
      # dep must match a cluster (on ocn)
      cluster
      # cluster must have commitments
      commitments
      # 1+ of those commitments must match organization
      org_commitments
      # 1+ of those commitments must be non-deprecated
      reject_deprecated
      # 1+ of those must match local_id
      local_id_matches
      # This should be the last-ish check, after all whittle-downs.
      multiple_matches?
    end

    private # private # private # private # private # private # private

    def validate!
      unless @allowed_status.include?(@status)
        raise ArgumentError, "Bad status \"#{@status}\""
      end
    end
  end
end
