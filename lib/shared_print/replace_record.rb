require "securerandom"

module SharedPrint
  class ReplaceRecord
    attr_reader :existing, :replacement
    def initialize(existing: nil, replacement: nil)
      @existing = existing
      @replacement = replacement
      validate
    end

    def validate
      raise ArgumentError, "Missing existing commitment" if @existing.nil?
      raise ArgumentError, "Missing replacement commitment" if @replacement.nil?

      # The replacement does not have to be a commitment that exists in the db.
      # It may need to autovivify upon replacing an old one, when reading from file.
      # Thus we may need to turn a Hash read from a file into a Clusterable::Commitment.
      if @replacement.instance_of?(Hash)
        @replacement = Clusterable::Commitment.new(@replacement)
      end

      unless @existing.instance_of?(Clusterable::Commitment)
        raise ArgumentError, "Existing commitment must be a Clusterable::Commitment"
      end

      unless @replacement.instance_of?(Clusterable::Commitment)
        raise ArgumentError, "Replacement must be a Clusterable::Commitment"
      end

      unless matches.size == 1
        raise IndexError, "Existing matches must be 1 (is #{matches.size})"
      end

      Clustering::ClusterCommitment.new(@replacement).cluster.tap(&:save)
    end

    # Replace :existing with :replacement.
    def apply
      # Sadly (?) this makes it so that all replaced commitments are deprecated with
      # the same status "E". Even if previously deprecated with another status.
      # Status "R" for Replaced was rejected because it would be meaningless.
      matches.first.deprecate(status: "E", replacement: @replacement)
      matches.first.save
    end

    # Original implementation that creates duplicate records with the same _ids in Mongo.
    def apply_broken
      @existing.deprecate(status: "E", replacement: @replacement)
      @existing.save
    end

    # In order to replace a commitment, we need to know how many matches there are for it.
    # Ideally, there should be only one.
    def matches
      @matches ||= SharedPrint::Finder.new(
        ocn: [@existing.ocn],
        organization: [@existing.organization],
        local_id: [@existing.local_id],
        deprecated: nil
      ).commitments.to_a
    end

    # After apply, replaced should return the freshly deprecated record.
    def replaced
      SharedPrint::Finder.new(
        ocn: [@existing.ocn],
        organization: [@existing.organization],
        local_id: [@existing.local_id],
        deprecated: true
      ).commitments.to_a.first
    end

    # Verify that the commitment supposed to get replaced did indeed get replaced.
    def verify
      replaced.deprecation_replaced_by.to_s == @replacement._id.to_s
    end

    def to_s
      "Replace commitment:\n#{@existing.inspect}\n...with:\n#{@replacement.inspect}"
    end
  end
end
