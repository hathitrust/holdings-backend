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
end
