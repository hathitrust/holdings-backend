# frozen_string_literal: true

require "services"
require "cluster"

Services.mongo!

module Reports
  # Given criteria, pull up all holdings that match those criteria
  # AND are eligible for commitments
  class EligibleCommitments

    def header
      ["ocn", "commitments"]
    end

    # also need methods on holdings that
    # 1) say if there is a matching commitment
    # 2) say if the HOLDING is eligible for commitments

    def for_ocns(ocns = [])
      if ocns.any?
        seen = {}
        ocns.sort.uniq.each do |ocn|
          cluster = Cluster.find_by(ocns: [ocn.to_i])

          if cluster.nil?
            yield [ocn, "NIL"]
            next
          end

          if seen.key?(cluster._id)
            next
          end

          seen[cluster._id] = true
          
          next unless cluster.eligible_for_commitments?
          yield [ocn, cluster.commitments?]
        end
      else
        raise "No ocns given"
      end
    end
  end
end
