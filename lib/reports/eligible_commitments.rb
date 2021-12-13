# frozen_string_literal: true

require "services"

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
        ocns.uniq.each do |ocn|
          cluster = Cluster.find_by(ocns: ocn.to_i)
          next if cluster.nil?
          next unless cluster.eligible_for_commitments?

          puts [ocn, cluster.commitments?].join("\t")
        end
        true
      else
        puts "No ocns given"
        false
      end
    end
  end
end
