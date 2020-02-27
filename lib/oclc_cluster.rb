# frozen_string_literal: true

require "forwardable"
require "oclc_number"

# A thin wrapper around array of OCLCNumber.
# Used by Mongo to hold `ocns`
class OCLCCluster < Array
  extend Forwardable

  def_delegators :ocns, :first
  attr_reader :ocns

  def initialize(ocns)
    @ocns = ocns.map {|o| OCLCNumber.new(o) }
  end

  # Convert to a Mongo friendly type
  def mongoize
    ocns.map(&:to_i)
  end

  def to_a
    ocns
  end

  class << self
    def demongoize(object)
      OCLCCluster.new(object)
    end

    # Mongoize any object given
    def mongoize(object)
      case object
      when OCLCCluster then object.mongoize
      when OCLCNumber then object.to_i
      else object
      end
    end
    alias_method :evolve, :mongoize
  end

end
