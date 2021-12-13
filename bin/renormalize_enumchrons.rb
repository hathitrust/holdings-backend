# frozen_string_literal: true

require "services"
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

def main
  batch_size = 1_000
  marker = Services.progress_tracker.new(batch_size)
  logger = Services.logger
  logger.info "Starting renormalization of enum chrons. Batches of #{ppnum batch_size}"

  records_with_enum_chrons.each do |rec|
    marker.incr
    renormalize(rec)
    marker.on_batch {|m| logger.info m.batch_line }
  end
  logger.info marker.final_line
end

main if __FILE__ == $PROGRAM_NAME
