# frozen_string_literal: true

require "mysql2"
require "services"

# Information about an individual HathiTrust institution
class HTMember
  attr_reader :inst_id, :country_code, :weight, :oclc_sym

  def initialize(inst_id:, country_code: nil, weight: nil, oclc_sym: nil)
    @inst_id = inst_id
    raise ArgumentError, "Must have institution id" unless @inst_id

    @country_code = country_code
    @weight = weight
    if @weight.nil? || (@weight < 0) || (@weight > 10)
      raise ArgumentError, "Weight must be between 0 and 10"
    end

    @oclc_sym = oclc_sym
  end
end

#
# Cache of information about HathiTrust members.
#
# Usage:
#
#   htm = HTMembers.new()
#   cc = htm["yale"].country_code
#   wt = htm["harvard"].weight
#
# This returns a hash keyed by member id that contains the country code, weight,
# and OCLC symbol.
#
# You can also pass in mock data for development/testing purposes:
#
#   htm = HTMembers.new({
#     "haverford" => HTMember.new(inst_id: "haverford", country_code: "us", weight: 0.67)
#   })
#   htm["haverford"].country_code
#   htm["haverford"].weight
#
class HTMembers

  attr_reader :members

  def initialize(members = load_from_db)
    @members = members
  end

  def load_from_db
    Services.holdings_db[:ht_billing_members]
      .select(:inst_id, :country_code, :weight, :oclc_sym)
      .as_hash(:inst_id)
      .transform_values {|h| HTMember.new(h) }
  end

  # Given a inst_id, returns a hash of data for that member.
  def [](inst_id)
    if @members.key?(inst_id)
      @members[inst_id]
    else
      raise KeyError, "No member_info data for inst_id:#{inst_id}"
    end
  end

  # Adds a temporary member to the member data cache for the lifetime of the
  # object; does not persist it to the database
  #
  # @param member The HTMember to add
  def add_temp(member)
    @members[member.inst_id] = member
  end

end
