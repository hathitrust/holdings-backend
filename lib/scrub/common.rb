# frozen_string_literal: true

require "services"

module Scrub
  class Common
    OCN_SPLIT_DELIM = /[,:;|\/ ]+/
    MAX_NUM_ITEMS = 25 # rather arbitrary
    # someone exported a big num from excel, e.g. 1.1e+567
    EXPONENTIAL = /\d[Ee]\+?\d/
    # 55NEW55
    DIGIT_MIX = /^\d+\D/
    # (ocolc)555 / (abc)555
    PAREN_PREFIX = /^\(.+?\)/
    # ocn555 / abc555
    PREFIX = /^\D+/
    # for capturing the numeric part
    NUMERIC_PART = /(\d+)/
    OK_PAREN_PREFIX = /\((oclc|ocm|ocn|ocolc|on)\)/i
    OK_PREFIX = /(oclc|ocm|ocn|ocolc|on)/i
    LOCAL_ID_SPLIT_DELIM = /[,; ]+/
    ISSN_DELIM = LOCAL_ID_SPLIT_DELIM
    ISSN = /^\d{4}-?\d{3}[0-9Xx]$/
    LOCAL_ID_MAX_LEN = 50
    def count_x(*x)
      str = x.join(", ")
      Services.scrub_stats[str] ||= 0
      Services.scrub_stats[str] += 1
    end
  end
end
