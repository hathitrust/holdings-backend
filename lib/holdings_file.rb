# frozen_string_literal: true

require "sequel"
require "services"

# Information about a file of records loaded into the system
class HoldingsFile < Sequel::Model(Services.holdings_db.rawdb[:holdings_files])
  # primary key isn't autogenerated; we need to set it at creation
  unrestrict_primary_key

  def self.latest(**kwargs)
    where(**kwargs).order_by(Sequel.desc(:produced)).limit(1).first
  end

  def self.from_object(obj)
    new(**Hash[columns.map {|column| [column, obj.public_send(column)] }])
  end

end
