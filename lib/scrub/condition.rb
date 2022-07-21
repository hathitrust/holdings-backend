# frozen_string_literal: true

require "scrub/simple_matcher"

module Scrub
  class Condition < Scrub::SimpleMatcher
    def regex
      /^BRT$/
    end

    def value
      @output
    end
  end
end
