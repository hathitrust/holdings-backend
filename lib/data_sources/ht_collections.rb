# frozen_string_literal: true

require "mysql2"
require "services"

module DataSources
  # An individual Collection record
  class HTCollection
    attr_reader :collection, :content_provider_cluster, :responsible_entity,
      :original_from_inst_id, :billing_entity

    def initialize(collection:, content_provider_cluster:, responsible_entity:,
      original_from_inst_id:, billing_entity:)
      @collection = collection
      @content_provider_cluster = content_provider_cluster
      @responsible_entity = responsible_entity
      @original_from_inst_id = original_from_inst_id
      @billing_entity = billing_entity
    end
  end
end

module DataSources
  #
  # Cache of information about HathiTrust collections.
  #
  # Usage:
  #
  #  htc = HTCollections.new()
  #  be = htc["MIU"].billing_entity
  #
  # This reeturns a hash keyed by member id that contains the collection code,
  # content provider cluster, responsible entity, orginal_from_inst_id, and billing entity.
  #
  # We are currently only interested in billing entity for overlap calculations.
  class HTCollections
    attr_reader :collections

    def initialize(collections = load_from_db)
      @collections = collections
    end

    def load_from_db
      Services.holdings_db[:ht_collections]
        .select(:collection,
          :content_provider_cluster,
          :responsible_entity,
          :original_from_inst_id,
          :billing_entity)
        .as_hash(:collection)
        .transform_values { |h| DataSources::HTCollection.new(**h) }
    end

    def [](collection)
      if @collections.key?(collection)
        @collections[collection]
      else
        raise KeyError, "No collection data for collection:#{collection}"
      end
    end
  end
end
