# frozen_string_literal: true

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
  # This returns a hash keyed by member id that contains the collection code,
  # content provider cluster, responsible entity, orginal_from_inst_id, and billing entity.
  #
  # We are currently only interested in billing entity for overlap calculations.
  class HTCollections
    CACHE_MAX_AGE_SECONDS = 3600

    attr_reader :collections

    def initialize(collections = data_from_db)
      load_data(collections)
    end

    def [](collection)
      collection_info(collection: collection)
    end

    private

    def data_from_db
      Services.collections_table
        .select(:collection,
          :content_provider_cluster,
          :responsible_entity,
          :original_from_inst_id,
          :billing_entity)
        .as_hash(:collection)
        .transform_values { |h| DataSources::HTCollection.new(**h) }
    end

    def load_data(collections)
      @collections = data_from_db
      @cache_timestamp = Time.now.to_i
    end

    def collection_info(collection:, retry_it: true)
      if Time.now.to_i - @cache_timestamp > CACHE_MAX_AGE_SECONDS
        load_data(data_from_db)
      end

      if @collections.key?(collection)
        @collections[collection]
      elsif retry_it
        load_data(data_from_db)
        collection_info(collection: collection, retry_it: false)
      else
        raise KeyError, "No collection data for collection:#{collection}"
      end
    end
  end
end
