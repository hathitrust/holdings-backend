require "shared_print/finder"
require "shared_print/phases"
require "utils/report_output"

# Output a .tsv report of which orgs have how many commitments in a phase.
# Defaults to latest (or, rather, _greatest_) phase.
module Reports
  class SharedPrintPhaseCount
    attr_reader :phase, :finder, :output
    def initialize(phase: SharedPrint::Phases.list.max)
      @phase = phase.to_i
      # Potentially use Reports::Dynamic instead of SharedPrint::Finder
      # (but SP::Finder does the trick just fine for now)
      @finder = SharedPrint::Finder.new(phase: [@phase])
      @output = Utils::ReportOutput.new("sp_phase#{@phase}_count")
    end

    def run
      # Get an output handle.
      handle = output.handle("w")
      puts "Started writing to #{output.file}"
      handle.puts(header)
      # Get relevant commitments, tally organizations.
      organization_tally = {}
      commitments do |commitment|
        organization_tally[commitment.organization] ||= 0
        organization_tally[commitment.organization] += 1
      end
      # Output tally.
      organization_tally.keys.sort.each do |org|
        handle.puts [org, phase, organization_tally[org]].join("\t")
      end
      puts "Finished writing to #{output.file}"
    ensure
      handle.close
    end

    def commitments
      return enum_for(:commitments) unless block_given?

      finder.commitments.each do |commitment|
        yield commitment
      end
    end

    def header
      ["organization", "phase", "commitment_count"].join("\t")
    end
  end
end
