# frozen_string_literal: true

require "services"
require "overlap/holding_commitment"

module Reports
  # User wants to find holdings for replacing shared print commitments.
  # Given criteria, pull up all clusters that  match those criteria
  # AND have holdings,
  # AND have ht_items,
  # AND for those clusters, report holdings that don't have a commitment.
  # Invoke via bin/reports/compile_commitment_replacements_report.rb
  class CommitmentReplacements
    def initialize(ocns = [])
      @ocns = ocns.map(&:to_i)
      if ocns.empty?
        raise ArgumentError, "No ocns given"
      end
    end

    def header
      ["organization", "oclc_sym", "ocn", "local_id"]
    end

    def replacements
      return enum_for(:replacements) unless block_given?

      ocns.sort.uniq.each do |ocn|
        overlap = Overlap::HoldingCommitment.new(ocn)
        overlap.eligible_holdings.each do |h|
          # Check that the holding does not have a matching commitment
          matching_commitments = overlap.active_commitments.select do |act_com|
            act_com.organization == h.organization && act_com.local_id == h.local_id
          end
          next if matching_commitments.any?
          yield [
            h.organization,
            Services.ht_organizations.members.fetch(h.organization)&.oclc_sym || "N/A",
            h.ocn,
            h.local_id
          ]
        end
      end
    end

    def run(output_filename = report_file)
      File.open(output_filename, "w") do |fh|
        fh.puts header.join("\t")
        replacements.each do |row|
          fh.puts row.join("\t")
          Thread.pass
        end
      end
    end

    private

    attr_reader :ocns

    def report_file
      FileUtils.mkdir_p(Settings.shared_print_report_path)
      iso_stamp = Time.now.strftime("%Y%m%d-%H%M%S")
      rand_str = SecureRandom.hex(8)
      File.join(Settings.shared_print_report_path, "eligible_commitments_#{iso_stamp}_#{rand_str}.txt")
    end
  end
end
