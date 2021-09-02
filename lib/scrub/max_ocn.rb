# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "../..", "lib"))
require "json"
require "services"

OCLC_URL = "https://www.oclc.org/apps/oclc/wwg"
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
      @log = Services.logger
    end

    def self.memo_loc
      "/tmp/max_ocn.txt"
    end

    def ocn
      if File.exist?(MaxOcn.memo_loc)
        @log.info "memo hit"
        mtime     = File.stat(MaxOcn.memo_loc).mtime.to_i
        epoch     = Time.now.to_i
        time_diff = epoch - mtime
        @log.info "time diff #{time_diff}"

        if time_diff > @age_limit
          @log.info "memo file too old"
          write_file
        else
          @log.info "memo file still good"
          read_file
        end
      else
        @log.info "memo miss"
        write_file
      end
    end

    private

    def write_file
      @log.info "writing new memo file"
      data = JSON.parse(make_call)
      f = File.open(MaxOcn.memo_loc, "w")
      @ocn = data["oclcNumber"].to_i
      f.puts @ocn
      f.close
      @ocn
    end

    def make_call
      if @mock
        @log.info "mock call"
        `cat spec/fixtures/max_oclc_response.json`
      else
        `curl -s "#{OCLC_URL}"`
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
