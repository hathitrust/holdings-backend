# frozen_string_literal: true

require "scrub/simple_matcher"

module Scrub
  class GovDoc < Scrub::SimpleMatcher
    def regex
      /^[01]$/
    end

    def value
      @output
    end
  end
end
