# frozen_string_literal: true

module Clustering
  # Wrapper for a retryable MongoDB operation on clusters. Can either create a
  # simple retryable operation or a retryable operation wrapped in a transaction.
  class Retryable
    MAX_RETRIES = 5
    # Not constantized by mongo gem
    MONGO_DUPLICATE_KEY_ERROR = 11_000

    def self.ensure_transaction(&block)
      if (s = Mongoid::Threaded.get_session)
        raise "In a session but not in a transaction??" unless s.in_transaction?

        yield
      else
        Cluster.with_session do |session|
          session.with_transaction(&block)
        end
      end
    end

    def self.with_transaction(&block)
      ensure_transaction do
        new.run(&block)
      end
    end

    def initialize
      @tries = 0
    end

    def run
      @tries = 0

      begin
        @tries += 1
        yield
      rescue Mongo::Error::OperationFailure, ClusterError => e
        @error = e
        retryable_error? && more_tries? && retry || raise
      end
    end

    def retryable_error?
      error.is_a?(ClusterError) ||
        error.code == MONGO_DUPLICATE_KEY_ERROR ||
        error.code_name == "WriteConflict"
    end

    def more_tries?
      if @tries < MAX_RETRIES
        Services.logger.warn "Got #{@error}, retrying (try #{@tries + 1})"
        true
      else
        false
      end
    end

    private

    attr_accessor :error, :tries
  end
end
