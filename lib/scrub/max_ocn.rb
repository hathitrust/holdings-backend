# frozen_string_literal: true

require "json"
require "open-uri"
require "services"

OCLC_URL = "https://www.oclc.org/apps/oclc/wwg"
MEMO_LOC = "/tmp/max_ocn.txt"
ONE_DAY_SEC = 86_400

module Scrub
  # Gets the current max OCN from OCLC.
  # Memoizes to file.
  # Usage:
  # require "scrub/max_ocn"
  # cur_max_ocn = Scrub::MaxOcn.new.ocn
  class MaxOcn
    def initialize(age_limit: ONE_DAY_SEC, mock: false)
      @age_limit = age_limit
      @mock = mock
    end

    def self.memo_loc
      MEMO_LOC
    end

    def current_max_ocn
      return_val = ocn
      if return_val.nil?
        raise "failed to set current_max_ocn"
      end
      return_val
    end

    def ocn
      if File.exist?(MaxOcn.memo_loc)
        if memo_expired?
          write_file
        else
          read_file
        end
      else
        write_file
      end
    end

    private

    def memo_expired?
      mtime = File.stat(MEMO_LOC).mtime.to_i
      epoch = Time.now.to_i
      time_diff = epoch - mtime
      time_diff > @age_limit
    end

    def write_file
      data = JSON.parse(make_call)
      f = File.open(MaxOcn.memo_loc, "w")
      @ocn = data["oclcNumber"].to_i
      f.puts @ocn
      f.close
      @ocn
    end

    def make_call
      if @mock
        IO.read("spec/fixtures/max_oclc_response.json")
      else
        URI.parse(OCLC_URL).open.read
      end
    end

    def read_file
      @ocn = IO.read(MaxOcn.memo_loc).strip.to_i
    end
  end
end

if $PROGRAM_NAME == __FILE__
  puts Scrub::MaxOcn.new.ocn
end
