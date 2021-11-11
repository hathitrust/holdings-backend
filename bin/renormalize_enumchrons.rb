# frozen_string_literal: true

require "services"
require "utils/waypoint"
require "utils/ppnum"
require "cluster"

Services.mongo!

def renormalize(item)
  item.normalize_enum_chron
  item.save
end

def records_with_enum_chrons
  return enum_for(:records_with_enum_chrons) unless block_given?

  Cluster.where("$or": [{ "holdings.enum_chron": { "$ne": "" } },
                        { "ht_items.enum_chron": { "$ne": "" } }]).each do |c|
                          (c.holdings + c.ht_items).each do |item|
                            yield item unless item.enum_chron == ""
                          end
                        end
end

if __FILE__ == $PROGRAM_NAME
  BATCH_SIZE = 1_000
  waypoint = Services.progress_tracker.new(BATCH_SIZE)
  logger = Services.logger
  logger.info "Starting renormalization of enum chrons. Batches of #{ppnum BATCH_SIZE}"

  records_with_enum_chrons.each do |rec|
    waypoint.incr
    renormalize(rec)
    waypoint.on_batch {|wp| logger.info wp.batch_line }
  end
  logger.info waypoint.finalize
end
