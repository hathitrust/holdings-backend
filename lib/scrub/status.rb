# frozen_string_literal: true

require "scrub/simple_matcher"

module Scrub
  class Status < Scrub::SimpleMatcher
    def regex
      /^(CH|LM|WD)$/
    end

    def value
      @output
    end
  end
end
