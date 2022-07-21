# frozen_string_literal: true

module Scrub
  class MalformedRecordError < StandardError
    # When there is enough wrong with a record to outright reject it
  end
end
