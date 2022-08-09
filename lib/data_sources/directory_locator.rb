require "services"

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
    attr_reader :base, :organization
    def initialize(base, organization)
      @base = base
      @organization = organization
      # In the off chance the object is created 1s before jan 1st,
      # at least we'll be consistent across the life of this object.
      @year = Time.new.year.to_s
    end

    def base
      join(@base, "#{organization}-hathitrust-member-data")
    end

    def holdings
      join(base, "print\ holdings")
    end

    def holdings_current
      join(holdings, @year)
    end

    def shared_print
      join(base, "shared\ print")
    end

    def analysis
      join(base, "analysis")
    end

    private

    def join(*arr)
      arr.join("/")
    end
  end
end
