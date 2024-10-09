
require "clusterable/holding"

# Matches a single holding against a set of criteria by projecting the holding
# down to the fields of the criteria, then checking if those values are in the
# set of criteria. All criteria must have the same fields.
class CompositeHoldingsCriteria

  attr_reader :criteria
  
  def initialize(*criteria)
    if(criteria.any? { |c| c.keys.to_set != criteria[0].keys.to_set })
      raise ArgumentError, "All criteria must have the same keys"
    end

    @keys = criteria[0].keys
    @criteria = criteria.to_set
  end

  def match?(holding)
    criteria.include?(project(holding))
  end

  private

  attr_reader :keys

  def project(holding)
    holding.slice(keys)
  end

end
