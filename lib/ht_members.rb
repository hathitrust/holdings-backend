# frozen_string_literal: true

# WIP: cache of information about HathiTrust members
class HTMembers

  def initialize(*members)
    @members = members.empty? ? load_from_db : members
  end

  def load_from_db
    # do that
  end

  def get_list
    @members
  end
end
