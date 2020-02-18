class Ht_members

  def initialize (*members)
    @members = members.empty? ? load_from_db : members;
  end

  def load_from_db
    # do that
  end

  def get_list
    return @members
  end
end
