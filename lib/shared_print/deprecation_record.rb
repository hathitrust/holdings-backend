# frozen_string_literal: true

require "cluster"
require "shared_print/deprecation_error"

module SharedPrint
  # Represents a line in a file of (shared print) deprecation requests,
  # and can try to find a Commitment that matches it.
  class DeprecationRecord
    attr_reader :organization, :ocn, :local_id, :status

    def initialize(organization: nil, ocn: nil, local_id: nil, status: nil)
      @ocn = ocn.to_i
      @organization = organization
      @local_id = local_id
      @status = status
      @allowed_status = ["C", "D", "E", "L", "M"]
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

    # OCN should lead to a cluster.
    def cluster
      @cluster ||= Cluster.where(ocns: @ocn).first
    end

    # The cluster should have commitments.
    def commitments
      @commitments ||= (cluster&.commitments || [])
    end

    # Cluster should have commitments by dep.organization.
    def org_commitments
      @org_commitments = commitments.select do |c|
        c.organization == @organization
      end
    end

    # There should be undeprecated commitments on the cluster.
    def undeprecated_commitments
      @undeprecated_commitments ||= org_commitments.select do |c|
        c.deprecated? == false
      end
    end

    # One of the undeprecated commitments should match the input local_id.
    def local_id_matches
      @local_id_matches = undeprecated_commitments.select do |c|
        c.local_id == @local_id
      end
    end

    # There should only be one match in the end.
    def validate_single_match
      local_id_matches.size == 1
    end

    # Start at cluster level, given ocn, and whittle down.
    # Raise error if at any point we have an unexpected number of things.
    def find_commitment
      raise SharedPrint::DeprecationError, "No cluster found for OCN:#{ocn}" if cluster.nil?
      raise SharedPrint::DeprecationError, "No commitments found in cluster" if commitments.empty?
      raise SharedPrint::DeprecationError, "No commitments by organization:#{organization} in cluster." if org_commitments.empty?
      raise SharedPrint::DeprecationError, "Only deprecated commitments found." if undeprecated_commitments.empty?
      raise SharedPrint::DeprecationError, "No commitment with local_id:#{@local_id} found" if local_id_matches.empty?
      unless validate_single_match
        raise SharedPrint::DeprecationError,
          "Multiple local_ids found:\n#{local_id_matches.map(&:inspect).join("\n")}"
      end
      local_id_matches.first
    end

    private

    def validate!
      unless @allowed_status.include?(@status)
        raise ArgumentError, "Bad status \"#{@status}\""
      end
    end
  end
end
