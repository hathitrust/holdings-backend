
require "clusterable/holding"

# Matches a single holding against a set of fields
class HoldingsCriteria < Hash

  attr_reader :criteria
  
  def initialize(**criteria)
    invalid_fields = criteria.keys.select { |k| ! Clusterable::Holding.fields.include?(k.to_s) }
    if invalid_fields.any?
      raise ArgumentError, "not fields of Holding: #{invalid_fields}"
    end

    super()
    self.merge!(criteria.transform_keys { |k| k.to_s })
  end

  def match?(holding)
    all? do |k,v|
      holding[k] == v
    end
  end
end
