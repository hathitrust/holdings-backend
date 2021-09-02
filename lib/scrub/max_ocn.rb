# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "../..", "lib"))
require "json"
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
    def initialize(age_limit = ONE_DAY_SEC)
      @log = Services.logger
      @age_limit = age_limit
    end

    def ocn
      if File.exist?(MEMO_LOC)
        @log.info "memo hit"
        mtime     = File.stat(MEMO_LOC).mtime.to_i
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
      res = `curl -s "#{OCLC_URL}"`
      data = JSON.parse(res)
      f = File.open(MEMO_LOC, "w")
      @ocn = data["oclcNumber"].to_i
      f.puts @ocn
      f.close
      @ocn
    end

    def read_file
      @ocn = IO.read(MEMO_LOC).strip.to_i
    end

  end
end

if $PROGRAM_NAME == __FILE__
  puts Scrub::MaxOcn.new.ocn
end
