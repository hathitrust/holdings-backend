module SharedPrint
  # A lookup object for which orgs are members of which shared print program,
  # and vice versa.
  class Groups
    attr_reader :groups

    def initialize
      @groups = {
        "coppul" => [
          "ucalgary",
          "ualberta"
        ],
        "east" => [
          "brandeis",
          "brynmawr",
          "bu",
          "colby",
          "lafayette",
          "nyu",
          "pitt",
          "rochester",
          "swarthmore",
          "tufts",
          "umd",
          "union"
        ],
        "flare" => ["flbog"],
        "mssc" => ["colby"],
        "recap" => [
          "columbia",
          "harvard",
          "nypl",
          "princeton"
        ],
        "ivyplus" => [
          "brown",
          "columbia",
          "cornell",
          "dartmouth",
          "duke",
          "harvard",
          "jhu",
          "mit",
          "princeton",
          "psu",
          "stanford",
          "uchigaco",
          "yale"
        ],
        "ucsp" => [
          "nrlf",
          "srlf",
          "ucmerced",
          "ucsc",
          "ucsd"
        ],
        "viva" => ["virgina"],
        "downsview" => ["utoronto"],
        "fdlp" => ["umn"]
      }

      @reverse = reverse_lookup
    end

    # Which orgs are members in a group?
    def group_to_orgs(group)
      groups[group]
    end

    # Which groups is an org in?
    def org_to_groups(org)
      @reverse[org]
    end

    private

    def reverse_lookup
      reverse = {}
      groups.each do |group, org_arr|
        org_arr.each do |org|
          reverse[org] ||= []
          reverse[org] << group
        end
      end
      reverse
    end
  end
end
