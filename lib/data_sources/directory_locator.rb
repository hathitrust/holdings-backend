require "services"

module DataSources
  # Given an organization name, provide locations to all their
  # remote and local directories to/from which files of importance
  # may be transferred.
  # locator = DataSources::DirectoryLocator.new("umich")
  # remote_holdings = locator.remote.holdings_current
  class DirectoryLocator
    attr_reader :organization, :remote, :local
    def initialize(organization)
      @organization = organization
      @remote = DataSources::RemoteDirectory.new(organization)
      @local = DataSources::LocalDirectory.new(organization)
    end
  end

  class RemoteDirectory
    attr_reader :organization
    def initialize(organization)
      @organization = organization
    end

    def base
      glue(
        Settings.remote_file_storage_base, # e.g. remote:#{dropbox_url} or /tmp/test
        "#{organization}-hathitrust-member-data"
      )
    end

    def holdings
      glue(base, "print\ holdings")
    end

    def holdings_current
      glue(holdings, Time.new.year.to_s)
    end

    def shared_print
      glue(base, "shared\ print")
    end

    def analysis
      glue(base, "analysis")
    end

    private

    def glue(*arr)
      arr.join("/")
    end
  end
end
