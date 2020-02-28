# frozen_string_literal: true

require "forwardable"

# An OCLCNumber. Treated as an immutable identifier that can be compared to
# other OCLCNumbers and used as a hash key, but that does not support
# arithmetic operations.
class OCLCNumber
  extend Forwardable

  def_delegators :ocn, :eql, :==, :hash, :to_i

  attr_reader :ocn

  def initialize(ocn)
    @ocn = ocn
  end

  def mongoize
    ocn.to_i
  end

  class << self
    def demongoize(object)
      OCLCNumber.new(object)
    end

    def mongoize(object)
      case object
      when OCLCNumber then object.to_i
      else object
      end
    end
    alias_method :evolve, :mongoize
  end
end
