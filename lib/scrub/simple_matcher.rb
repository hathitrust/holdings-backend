# frozen_string_literal: true

require "scrub/common"

module Scrub
  class SimpleMatcher < Scrub::Common
    def initialize(str)
      @output = []
      str = str.strip
      if str.empty?
        count_x("#{self.class}:<empty>")
      else
        match = regex.match(str)
        if match.nil?
          Services.scrub_logger.warn "bad #{self.class} value: \"#{str}\""
        else
          @output << match[0]
        end
      end
      count_x("#{self.class}:#{str}")
    end
  end
end
