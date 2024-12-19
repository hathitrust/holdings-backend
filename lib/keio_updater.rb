require "cluster"
require "services"

class KeioUpdater
  def initialize(limit = nil)
    raise "not implemented"
    @limit = limit
  end

  def limit_query(query)
    if @limit.nil?
      Cluster.where(**query)
    else
      Cluster.where(**query).limit(@limit)
    end.no_timeout
  end

  def run
    query = {
      "ht_items.0": {"$exists": 1},
      "ht_items.collection_code": "KEIO",
      "ht_items.billing_entity": "hathitrust"
    }

    limit_query(query).each do |cluster|
      cluster.ht_items.each do |ht_item|
        if ht_item.collection_code == "KEIO" && ht_item.billing_entity == "hathitrust"
          ht_item.billing_entity = "keio"
          Services.logger.info "Set billing_entity=keio on ocns:#{cluster.ocns}, item_id:#{ht_item.item_id}"
        end
      end
      cluster.save
    end
  end
end

if __FILE__ == $0
  limit = ARGV.shift
  KeioUpdater.new(limit).run
end
