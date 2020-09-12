# frozen_string_literal: true

require "cluster"
require "reclusterer"
require "cluster_error"

# Services for batch loading HT items
class ClusterHtItem

  MAX_RETRIES=5
  # Not constantized by mongo ge
  MONGO_DUPLICATE_KEY_ERROR=11_000

  def initialize(ocns = [])
    @ocns = ocns
  end

  def cluster(htitems)
    retry_operation do
      cluster_for_ocns.tap do |cluster|
        puts "adding htitems #{htitems.inspect} with ocns #{@ocns} to cluster #{cluster.inspect}"
        update_or_add_htitems(cluster,htitems)
      end
    end
  end

  # Move an HTItem from one cluster to another
  #
  # @param new_cluster - the cluster to move to
  def move(ht_item, new_cluster)
    unless new_cluster.id == ht_item._parent.id
      Cluster.with_transaction do
        duped_htitem = ht_item.dup
        ht_item.delete
        new_cluster.ht_items << duped_htitem
      end
    end
  end

  # Removes an HTItem
  def delete(ht_item)
    # Don't start a transaction until we know there's something we need to
    # delete, but if we do need to delete the thing then we need to re-fetch it
    # so we can acquire the correct lock
    retry_operation do
      return unless Cluster.with_ht_item(ht_item).first

      Cluster.with_transaction do
        if (cluster = Cluster.with_ht_item(ht_item).first)
          delete_htitem_and_recluster(cluster,ht_item)
        end
      end
    end
  end

  private

  def delete_htitem_and_recluster(cluster,ht_item)
    puts "removing old htitem #{ht_item.item_id}"
    cluster.ht_item(ht_item.item_id).delete

    # Note that technically we only need to do this if there were multiple
    # OCNs for that HT item and nothing else binds the cluster together.
    # It may be worth optimizing not to do this if the htitem has only one
    # OCN, since that will be the common case. Probably not worth checking
    # that nothing else binds the cluster together?
    Reclusterer.new(cluster).recluster
  end

  def cluster_for_ocns
    existing_cluster_with_ocns.tap { |c| puts "Got existing cluster #{c.inspect}" if c} || Cluster.create(ocns: @ocns).tap { |c| puts "Created cluster #{c.inspect}" }
  end

  def existing_cluster_with_ocns
    return unless @ocns.any?

    Cluster.merge_many(Cluster.for_ocns(@ocns)).tap do |c|
      c&.add_to_set(ocns: @ocns)
    end
  end

  def update_or_add_htitems(cluster,htitems)
    puts "Cluster #{cluster.inspect}: adding htitems #{htitems.inspect} with ocns #{@ocns}"
    to_append = []
    htitems.each do |item|
      if (existing_item = cluster.ht_item(item.item_id))
        puts "updating existing item with id #{item.item_id}"
        existing_item.update_attributes(item.to_hash)
      else
        delete(item)
        to_append << item
      end
    end

    if(to_append.length > 0)
      docs = to_append.map(&:as_document)
      result = cluster.collection.update_one( { _id: cluster._id }, { "$push" => { :ht_items => { "$each" => docs } } }, session: Cluster.session )
      raise ClusterError, "#{cluster.inspect} deleted before update" unless result.modified_count > 0

      to_append.each do |item|
        item.parentize(cluster)
        item._association = cluster.ht_items._association
        item.cluster=cluster
      end
      cluster.reload
    end
  end

  def retry_operation
    tries = 0

    begin
      tries += 1
      yield
    rescue Mongo::Error::OperationFailure => e
      handle_batch_error?(e, tries, retryable_error?(e)) && retry || raise
    rescue ClusterError => e
      handle_batch_error?(e, tries) && retry || raise
    end
  end

  def retryable_error?(error)
    error.code == MONGO_DUPLICATE_KEY_ERROR || error.code_name == "WriteConflict" 
#    error.code == MONGO_DUPLICATE_KEY_ERROR
  end

  def handle_batch_error?(exception, tries, condition=true)
    if condition && tries < MAX_RETRIES
      warn "Got #{exception} while processing #{@ocns}, retrying (try #{tries+1})"
      true
    else
      false
    end
  end

end
