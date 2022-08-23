# frozen_string_literal: true

require "utils/file_transfer"

module DataSources
  # Given a base and and org id, provide paths (strings) to the org's dirs.
  # Assumes identical structure on the remote and local side,
  # just with a different base path, and does not know/care if the paths
  # that it provides actually point to anything real.
  # E.g.:
  # remote_d = DataSources::DirectoryLocator.new("dropbox:foo/bar/member_data", "foo")
  # local_d = DataSources::DirectoryLocator.new("/tmp/member_data", "foo")
  # remote_holdings = remote_d.holdings_current
  # local_holdings = local_d.holdings_current
  class DirectoryLocator
    attr_reader :root, :organization
    def initialize(root, organization)
      @root = root # the part of the file system where the member directories start
      @organization = organization
      # In the off chance the object is created 1s before jan 1st,
      # at least we'll be consistent across the life of this object.
      @year = Time.new.year.to_s
    end

    # The base directory for the organization.
    def base
      File.join(@root, "#{organization}-hathitrust-member-data")
    end

    # The holdings parent directory for the organization
    def holdings
      File.join(base, "print\ holdings")
    end

    # The current-year holdings directory
    def holdings_current
      File.join(holdings, @year)
    end

    # The shared print directory (not divided into years like holdings are)
    def shared_print
      File.join(base, "shared\ print")
    end

    # This is where HT uploads reports and such for the member to access.
    def analysis
      File.join(base, "analysis")
    end

    # Ensure that each expected path points to an existing dir (mkdir if not)
    def ensure!
      @ft ||= Utils::FileTransfer.new
      @ft.mkdir_p(holdings_current)
      @ft.mkdir_p(shared_print)
      @ft.mkdir_p(analysis)
    end
  end
end
