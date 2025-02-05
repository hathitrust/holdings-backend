# frozen_string_literal: true

require "cluster"

# Calculates the format for HT Items and OCN Clusters
class CalculateFormat
  def initialize(cluster)
    @cluster = cluster
  end

  # Calculate format for this particular ht_item in this particular cluster
  #
  # @param ht_item, the HT item to calculate the format on.
  def item_format(ht_item)
    if ht_item.bib_fmt == "SE"
      "ser"
    elsif record_has_any_enum? ht_item
      "mpm"
    else
      "spm"
    end
  end

  # Calculate format for this entire OCN cluster
  def cluster_format
    if any_of_format? "mpm"
      "mpm"
    elsif any_of_format?("spm") && any_of_format?("ser")
      "ser/spm"
    elsif any_of_format?("ser")
      "ser"
    else
      "spm"
    end
  end

  private

  def any_of_format?(format)
    @cluster.ht_items.any? { |ht| item_format(ht) == format }
  end

  def record_has_any_enum?(ht_item)
    @cluster.ht_items.any? do |ht|
      ht.ht_bib_key == ht_item.ht_bib_key && !ht.n_enum&.empty?
    end
  end
end
