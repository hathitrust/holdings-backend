# frozen_string_literal: true

require "mysql2"
require "services"

module DataSources
  # Information about an individual HathiTrust institution
  class HTOrganization
    attr_reader :inst_id, :country_code, :weight, :oclc_sym, :status

    def initialize(inst_id:, country_code: nil, weight: nil, oclc_sym: nil, status: true)
      @inst_id = inst_id
      raise ArgumentError, "Must have institution id" unless @inst_id

      @country_code = country_code
      @weight = weight.to_f
      if @weight.nil? || (@weight < 0) || (@weight > 10)
        raise ArgumentError, "Weight must be between 0 and 10"
      end

      @oclc_sym = oclc_sym
      @status = status
    end
  end

  #
  # Cache of information about HathiTrust organizations.
  #
  # Usage:
  #
  #   htm = DataSources::HTOrganizations.new()
  #   cc = htm["yale"].country_code
  #   wt = htm["harvard"].weight
  #
  # This returns a hash keyed by member id that contains the country code, weight,
  # and OCLC symbol.
  #
  # You can also pass in mock data for development/testing purposes:
  #
  #   htm = DataSources::HTOrganizations.new({
  #     "haverford" => DataSources::HTOrganization.new(inst_id: "haverford",
  #                                    country_code: "us", weight: 0.67)
  #   })
  #   htm["haverford"].country_code
  #   htm["haverford"].weight
  #
  class HTOrganizations
    attr_reader :organizations

    def initialize(organizations = load_from_db)
      @organizations = organizations
    end

    def load_from_db
      Services.holdings_db[:ht_billing_members]
        .select(:inst_id, :country_code, :weight, :oclc_sym, :status)
        .as_hash(:inst_id)
        .transform_values { |h| HTOrganization.new(**h) }
    end

    # Given a inst_id, returns a hash of data for that member.
    def [](inst_id)
      if @organizations.key?(inst_id)
        @organizations[inst_id]
      else
        raise KeyError, "No organization_info data for inst_id:#{inst_id}"
      end
    end

    # A list of organizations that are actually members, i.e. status.true?
    def members
      @organizations.select { |_k, org| org.status }
    end

    # Adds a temporary organization to the organization data cache for the lifetime of the
    # object; does not persist it to the database
    #
    # @param organization The HTOrganization to add
    def add_temp(organization)
      @organizations[organization.inst_id] = organization
    end
  end
end
