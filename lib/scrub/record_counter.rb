require "scrub/scrub_output_structure"
require "settings"
require "utils/line_counter"

module Scrub
  class RecordCounter
    attr_reader :organization, :item_type, :struct, :message
    def initialize(organization, item_type)
      @organization = organization
      @item_type = item_type
      @struct = Scrub::ScrubOutputStructure.new(organization)
      @rx = /^#{@organization}_#{@item_type}_.+\.ndj$/
      @message = []

      if Settings.scrub_line_count_diff_max.nil?
        raise ArgumentError, "Missing Settings.scrub_line_count_diff_max"
      end
      if Settings.scrub_ocn_diff_max.nil?
        raise ArgumentError, "Missing Settings.scrub_ocn_diff_max"
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
        line_diff_ok = line_diff < Settings.scrub_line_count_diff_max
        ocn_diff_ok = ocn_diff < Settings.scrub_ocn_diff_max

        unless line_diff_ok
          @message << [
            "Line diff too great.",
            "Most recently loaded file (#{File.basename(last_loaded)}) line count: #{count_loaded}.",
            "The current file (#{File.basename(last_ready)}) line count: #{count_ready}.",
            "Line count diff: #{line_diff * 100}% (max allowed #{Settings.scrub_line_count_diff_max * 100}%)."
          ].join(" ")
        end

        unless ocn_diff_ok
          @message << [
            "Distinct OCN diff too great.",
            "Most recently loaded file (#{File.basename(last_loaded)}) ocn count: #{count_loaded_ocns}.",
            "The current file (#{File.basename(last_ready)}) OCN count: #{count_ready_ocns}.",
            "Distinct OCN diff: #{ocn_diff * 100}% (max allowed #{Settings.scrub_ocn_diff_max * 100}%)."
          ].join(" ")
        end

        line_diff_ok && ocn_diff_ok
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

    def count_loaded_ocns
      @count_loaded_ocns ||= count_distinct_ocns(last_loaded)
    end

    def count_ready_ocns
      @count_ready_ocns ||= count_distinct_ocns(last_ready)
    end

    def line_diff
      @line_diff ||= ((count_ready - count_loaded) / count_loaded.to_f).abs
    end

    def ocn_diff
      @ocn_diff ||= ((count_ready_ocns - count_loaded_ocns) / count_loaded_ocns.to_f).abs
    end

    private

    def count(path)
      if path.nil?
        0
      else
        Utils::LineCounter.new(path).count_lines
      end
    end

    def count_distinct_ocns(path)
      if path.nil?
        return 0
      end

      ocns = Set.new
      # Expecting file to be a .ndj, so we want to parse each line as JSON.
      File.open(path) do |f|
        f.each_line do |line|
          holding_hash = JSON.parse(line)
          next unless holding_hash.is_a? Hash
          next unless holding_hash.key?("ocn")
          ocns << holding_hash["ocn"]
        rescue JSON::ParserError
          warn "#{path} contains non-JSON"
        end
      end

      ocns.size
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
