# frozen_string_literal: true

require "cluster"

# This class provides a Cluster that contains the OCNs you want. There are
# effectively three strategies:
#
# - Fetch an existing cluster that has the OCNs you want
# - Merge multiple clusters together to get a single one with the OCNs you want
# - Make a new cluster with the OCNs
# # TODO rename to ClusterGetter or something?
class ClusterGetter
  def self.for(ocns)
    if block_given?
      Retryable.new.run do
        new(ocns).get.tap {|c| yield c }
      end
    else
      new(ocns).get
    end
  end

  def initialize(ocns)
    @ocns = ocns
  end

  def get
    find_or_merge || Cluster.create(ocns: @ocns)
  end

  private

  # @return A single cluster that contains all the members & OCNs of the
  # original clusters, or nil if there is no appropriate cluster.
  def find_or_merge
    return unless @ocns.any?

    # The clusters we find might change if the transaction gets aborted, but
    # we also don't need to start a transaction unless we find there are
    # multiple clusters that have to be merged. So, we retry the entire
    # operation, but don't start a transaction until we know we actually need
    # to merge clusters.

    @clusters=Cluster.for_ocns(@ocns)
    @target = @clusters.shift

    return @target if @target.nil? || @clusters.empty?

    merge
  end

  def merge
    Retryable.ensure_transaction do
      @clusters.each do |source|
        raise ClusterError, "clusters disappeared, try again" if source.nil?
        next if source._id == @target._id

        source.delete
        @target.add_members_from(source)
        @target.add_to_set(ocns: source.ocns)
        Services.logger.debug "Deleted cluster #{source.inspect} (merged into #{@target.inspect})"
      end
      @target.add_to_set(ocns: @ocns)
    end
  end

end
