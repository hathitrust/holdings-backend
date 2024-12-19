require "cluster"
require "services"

# A (ideally) one-time solution to update mono_multi_serial values.
# Usage:
# bundle exec ruby bin/update_item_type.rb 0
# ...
# bundle exec ruby bin/update_item_type.rb f

# Divide the collection by the last char in the Cluster._id
id_last_char = ARGV.shift
unless (("a".."f").to_a + ("0".."9").to_a).include?(id_last_char)
  raise "provide a char 0..f to divide clusters by"
end

log = File.open("/tmp/update_item_type_#{id_last_char}.log", "w")
log.puts "Start time: #{Time.now}"
puts "logging to #{log.path}"

old_item_type_rx = /^(mono|multi|serial)$/
old_to_new = {
  "mono" => "spm",
  "multi" => "mpm",
  "serial" => "ser"
}

clusters_changed_count = 0
holdings_changed_count = 0
marker = Services.progress_tracker.call(batch_size: 1000)

# For each cluster:
begin
  Cluster.each do |c|
    unsaved_changes = false
    current_cluster_id = c._id.to_s
    next unless current_cluster_id.end_with?(id_last_char)
    marker.incr
    marker.on_batch do |m|
      log.puts "clusters_changed_count:#{clusters_changed_count}"
      log.puts "holdings_changed_count:#{holdings_changed_count}"
      log.puts m.batch_line
    end
    # Check if the cluster has any holdings, and if so:
    if c.holdings.any?
      c.holdings.each do |h|
        # If holding has an old item type, update it to a new item type
        if h["mono_multi_serial"].match(old_item_type_rx)
          h["mono_multi_serial"] = old_to_new[h["mono_multi_serial"]]
          unsaved_changes = true
          holdings_changed_count += 1
        end
      end
      # Save cluster if any changes were made.
      if unsaved_changes
        c.save!
        clusters_changed_count += 1
      end
    end
  rescue => e # whatever the error
    log.puts "crashed on cluster #{current_cluster_id}"
    log.puts e
    raise "crashed\n#{e}"
  end
ensure
  log.puts "clusters_changed_count:#{clusters_changed_count}"
  log.puts "holdings_changed_count:#{holdings_changed_count}"
  log.puts marker.final_line
  log.close
end
