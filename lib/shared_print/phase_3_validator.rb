# frozen_string_literal: true

require "cluster"
require "loader/shared_print_loader"
require "services"
Services.mongo!

module SharedPrint
  class Phase3Error < StandardError
    # Any error occurring during pass_validation?(commitment) should be of this class.
  end

  class Phase3Validator
    attr_reader :path, :last_error, :log

    def initialize(path)
      @path = path
      @last_error = nil
      @log = nil

      # Any commitment in Phase 3 should have 1+ of these policies:
      @phase_3_required_policies = ["blo", "non-circ"]

      # Setup dirs
      if Settings.local_report_path.nil?
        raise "Missing Settings.local_report_path"
      end
      FileUtils.mkdir_p(Settings.local_report_path)
    end

    # Check all commitments in file and load the valid ones,
    # log both loaded and non-valid commitments to file.
    def run
      # Setup log files
      base = File.basename(@path)
      @log = File.open(File.join(Settings.local_report_path, base) + ".log", "w")
      @log.puts "Checking if commitments in #{@path} are valid..."
      # Go through input and process
      loader = Loader::SharedPrintLoader.for(@path)
      handle = Loader::SharedPrintLoader.filehandle_for(@path)
      handle.each do |line|
        # commitment is an unsaved commitment until it has passed
        # validation and is then saved by load()
        commitment = loader.item_from_line(line)
        if pass_validation? commitment
          loader.load commitment
          @log.puts "Loaded #{commitment.inspect}"
        else
          @log.puts "Failed to load #{commitment.inspect}"
        end
      end
    ensure
      # Close log files
      @log.puts "Done."
      @log.close
    end

    # Check if a given commitment is valid (for the phase 3 definition of valid).
    # Log errors.
    def pass_validation?(commitment)
      @last_error = nil
      require_valid_commitment(commitment)

      # Check that a valid cluster with matching OCN exists
      ocn = commitment.ocn
      cluster = Cluster.find_by(ocns: ocn)
      require_matching_cluster(cluster)
      require_valid_cluster(cluster)
      require_cluster_ht_items(cluster)

      # Check that org has a matching holdings record in the cluster
      require_matching_org_holding(cluster, commitment.organization)
      # Check that commitment satisfies phase 3 policy rules
      require_phase_3_policies(commitment)
      # We made it. The commitment should be safe to load.
      true
    rescue SharedPrint::Phase3Error => err
      # Any Phase3Error raised in pass_validation?() should get processed here
      report_error(commitment, err)
      false
    end

    def require_valid_commitment(commitment)
      unless commitment.valid?
        raise SharedPrint::Phase3Error, "Commitment not valid: #{commitment.errors.inspect}"
      end
    end

    def require_matching_cluster(cluster)
      if cluster.nil?
        raise SharedPrint::Phase3Error, "Commitment has no matching cluster"
      end
    end

    def require_valid_cluster(cluster)
      unless cluster.valid?
        raise SharedPrint::Phase3Error, "Commitment has an invalid matching cluster"
      end
    end

    def require_cluster_ht_items(cluster)
      if cluster.ht_items.empty?
        raise SharedPrint::Phase3Error, "Cluster has no ht_items"
      end
    end

    def require_matching_org_holding(cluster, org)
      if cluster.holdings.count { |h| h.organization == org }.zero?
        raise SharedPrint::Phase3Error, "Commitment has no matching holdings"
      end
    end

    def require_phase_3_policies(commitment)
      pols = commitment.policies
      # pols must match ONE AND ONLY ONE of the required policies.
      unless (pols & @phase_3_required_policies).count == 1
        msg = "Required policies mismatch. Commitment has #{pols.join(",")}. " \
              "Exactly one of #{@phase_3_required_policies.join(",")} is required"
        raise SharedPrint::Phase3Error, msg
      end
    end

    # Log errors to file and save the last one in @last_err
    def report_error(commitment, err)
      @last_error = err
      @log&.puts "Commitment not valid:"
      @log&.puts "* Inspect: #{commitment.inspect}"
      @log&.puts "* Message: #{err.message}"
      @log&.puts "---"
    end
  end
end
