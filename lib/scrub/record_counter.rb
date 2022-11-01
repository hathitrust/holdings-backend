require "scrub/scrub_output_structure"
require "settings"
require "utils/line_counter"

module Scrub
  class RecordCounter
    attr_reader :organization, :item_type, :struct
    def initialize(organization, item_type)
      @organization = organization
      @item_type = item_type
      @struct = Scrub::ScrubOutputStructure.new(organization)
      @rx = /^#{@organization}_#{@item_type}_.+\.ndj$/
      if Settings.scrub_line_count_diff_max.nil?
        raise ArgumentError, "Missing Settings.scrub_line_count_diff_max"
      end
    end

    # Compare loaded and ready and see if the size diff is acceptable,
    # or if we need to tell the humans about this.
    def acceptable_diff?
      if count_ready.zero?
        # "There is nothing new to load."
        false
      elsif count_loaded.zero?
        # "No previous records loaded for #{@organization}. Any diff is OK."
        true
      else
        # Check if the percent diff is less than the diff_max
        diff < Settings.scrub_line_count_diff_max
      end
    end

    def last_loaded
      @last_loaded ||= last_file(@struct.member_loaded)
    end

    def last_ready
      @last_ready ||= last_file(@struct.member_ready_to_load)
    end

    def count_loaded
      @count_loaded ||= count(last_loaded)
    end

    def count_ready
      @count_ready ||= count(last_ready)
    end

    def diff
      @diff ||= ((count_ready - count_loaded) / count_loaded.to_f).abs
    end

    private

    def count(path)
      if path.nil?
        0
      else
        Utils::LineCounter.count_file_lines(path)
      end
    end

    def last_file(path)
      matching_entries = path.entries.select { |f| f.match?(@rx) }
      if matching_entries.empty?
        nil
      else
        File.join(path, matching_entries.max)
      end
    end
  end
end
