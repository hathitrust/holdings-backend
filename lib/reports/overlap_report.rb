require "cluster"
require "services"

Services.mongo!

module Reports
  class OverlapReport
    # Runs an overlap report based on all the holdings of an organization
    # and also 1+ of:
    # * ph overlap (count other orgs w/ holdings overlap)
    # * htdl overlap (count vols w/ overlap)
    # * sp overlap (how many orgs have shared print overlap)
    # Example:
    # $ phctl report organization-holdings-overlap --organization=colby --ph --sp
    def initialize(organization: nil, ph: nil, htdl: nil, sp: nil)
      @organization = organization
      @ph = ph
      @htdl = htdl
      @sp = sp
      validate!
    end

    # Check inputs
    def validate!
      valid = true
      unless @organization.is_a?(String)
        Services.logger.warn "organization must be a string"
        valid = false
      end

      unless [@ph, @htdl, @sp].any?
        Services.logger.warn "At least one of ph/htdl/sp must be set"
        valid = false
      end

      unless valid
        raise "Check warnings, fix inputs, and run again."
      end
    end

    # Fetch data, format, and output.
    def run
      File.open(outf_path, "w") do |outf|
        outf.puts header.join("\t")
        clusters.each do |cluster|
          cluster_ph = count_cluster_ph(cluster)
          cluster_htdl = count_cluster_htdl(cluster)
          cluster_sp = count_cluster_sp(cluster)
          cluster.holdings.select { |h| h.organization == @organization }.each do |hol|
            outf.puts row(hol, cluster_ph, cluster_htdl, cluster_sp).join("\t")
          end
        end
      end
    end

    # Get output location
    def outf_path
      if @outf_path.nil?
        dir = Settings.overlap_report_path
        if dir.nil?
          Services.logger.warn "Settings.overlap_report_path not set, defaulting to /tmp"
          dir = "/tmp"
        end
        ts = Time.now.strftime("%Y%m%d")
        uuid = SecureRandom.uuid
        @outf_path = "#{dir}/overlap_#{@organization}_#{ts}_#{uuid}.tsv"
      end
      @outf_path
    end

    # Array of header labels for the header line of the report
    def header
      @header ||= [
        "ocn",
        "local_id",
        (@ph ? "ph_overlap" : nil),
        (@htdl ? "htdl_overlap" : nil),
        (@sp ? "sp_overlap" : nil)
      ].compact # removes the nils
    end

    # Override method to get a more specific query, or pass in different param
    def clusters(query: {"holdings.organization": @organization})
      return enum_for(:clusters) unless block_given?

      Cluster.where(query).each do |cluster|
        yield cluster
      end
    end

    # Formats an array of output values for a row of the report
    def row(hol, cluster_ph, cluster_htdl, cluster_sp)
      output = [
        hol.ocn,
        hol.local_id
      ]
      output << cluster_ph if @ph
      output << cluster_htdl if @htdl
      output << cluster_sp if @sp

      output
    end

    # If @ph is set, count how many orgs have holdings in the cluster
    def count_cluster_ph(cluster)
      if @ph
        cluster
          .holdings
          .select(&:organization)
          .uniq
          .count
      end
    end

    # If @htdl is set, count how many ht_items are in the cluster
    def count_cluster_htdl(cluster)
      if @htdl
        cluster
          .ht_items
          .count
      end
    end

    # If @sp is set, count how many members have (non-deprecated) commitments in the cluster
    def count_cluster_sp(cluster)
      if @sp
        cluster
          .commitments
          .select { |spc| !spc.deprecated? }
          .select(&:organization)
          .uniq
          .count
      end
    end
  end
end
