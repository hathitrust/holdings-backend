# frozen_string_literal: true

require "mysql2"
require "dotenv"

Dotenv.load(".env")

=begin

Cache of information about HathiTrust members
The data may be mocked if you pass it in to new(),
otherwise it will try to read it from db, and if that fails
it will use canned data (CANNED_DATA).

@mocked and @canned are set accordingly and readable, so you can
tell where the data is coming from

Usage:

  htm = HTMembers.new()
  puts "using canned data? #{htm.canned}"
  cc = htm.get("yale")["country_code"]
  wt = htm.get("harvard")["weight"]

Or if you want to provide your own mock data:

  htm = HTMembers.new({
    "haverford" => {
      "country_code" => "us",
      "weight"       => 0.67,
    }
  })
  puts "using canned data? #{htm.canned}"
  puts "using mocked data? #{htm.mocked}"
  htm.get("haverford")["country_code"]
  htm.get("haverford")["weight"]

=end

class HTMembers
  def self.template(cc, wt)
    {
      "country_code" => cc,
      "weight"       => wt
    }
  end

  SQL = %w<
    SELECT DISTINCT IF(mapto_inst_id='universityofcalifornia', inst_id, mapto_inst_id) AS member_id,
    country_code,
    weight
    FROM ht_institutions
    WHERE enabled = '1'
  >.join(' ')

  CANNED_DATA = {
    "brocku"  => HTMembers.template("ca", 0.67),
    "harvard" => HTMembers.template("za", 1.33),
    "umich"   => HTMembers.template("us", 1.33),
    "yale"    => HTMembers.template("us", 1.33),
  }

  attr_reader :mocked, :canned, :members
  def initialize(members = {})
    @mocked  = !members.empty?
    @canned  = false
    @members = @mocked ? members : load_from_db
  end

  # Are all the ENV vars required for DB connection set?
  def db_env_set?
    problem = false
    %w[HOST USERNAME PASSWORD PORT DATABASE].each do |name_part|
      name = "MYSQL_#{name_part}";
      # ENV[name] must be set, non-nil and non-empty.
      if !ENV.key?(name) || ENV[name].nil? || ENV[name].empty? then
        warn "ENV[#{name}] not set correctly (#{ENV[name]})"
        problem = true
      end
    end

    return !problem
  end

  def load_from_db
    data = {}
    # Attempt loading from db, use canned data if it fails.
    begin
      mysql_client = Mysql2::Client.new(
        :host     => ENV["MYSQL_HOST"],
        :username => ENV["MYSQL_USERNAME"],
        :password => ENV["MYSQL_PASSWORD"],
        :port     => ENV["MYSQL_PORT"],
        :database => ENV["MYSQL_DATABASE"],
        :connect_timeout => 5,
      )

      res = mysql_client.query(SQL)
      res.each do |row|
        data[row[:member_id]] = HTMembers.template(
          row["country_code"], row["weight"]
        )
      end
    rescue Mysql2::Error::ConnectionError => e
      warn "#{__FILE__} is using canned data"
      data    = CANNED_DATA
      @canned = true
    end

    return data
  end

  # Given a member_id, returns a hash of data for that member.
  def get(member_id)
    if @members.key?(member_id) then
      @members[member_id]
    else
      warn "No member_info data for member_id:#{member_id}"
      {"country_code" => "xx", "weight" => 0.0}
    end
  end

end

if $0 == __FILE__ then
  # Use db/canned
  htm = HTMembers.new()
  puts "using canned data? #{htm.canned}"
  puts "using mocked data? #{htm.mocked}"
  puts htm.get("umich")["country_code"]
  puts htm.get("harvard")["weight"]

  # Mock your own
  htm2 = HTMembers.new(
    {"harvard" => {"country_code" => "us", "weight" => 1.33}}
  )
  puts "using canned data? #{htm2.canned}"
  puts "using mocked data? #{htm2.mocked}"
  puts htm2.get("umich")["country_code"]
  puts htm2.get("harvard")["weight"]
end
