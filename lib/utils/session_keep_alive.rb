# frozen_string_literal: true

require "services"
require "cluster"

module Utils
  # Lets you wrap a session around a potentially long running query,
  # and that session is kept alive by a refresh-loop in a separate thread.
  # The actual test of keeping session/cursor alive is TODO.
  # Intended usage:
  # require "utils.session_keep_alive"
  # ska = Utils::SessionKeepAlive.new(60)
  # ska.run do
  #   # Mongo operation at risk of timing out:
  #   Cluster.where(long_q).no_timeout.each do |cluster|
  #     {...}
  #   end
  # end
  class SessionKeepAlive
    attr_reader :seconds, :refresh_count, :refresher_thread

    def initialize(seconds = 120)
      raise "remove me"
      @seconds = seconds # refresh freq, can be a float if you want to go below 1s.
      @refresh_count = 0 # For testing purposes, mostly.
      @refresher_thread = nil # The thread that refreshes the session.
    end

    def run(&_block)
      Cluster.with_session do |session|
        @refresher_thread = start_refresh_thread(session)
        yield # i.e. execute _block
      ensure
        @refresher_thread.kill
      end
    end

    private

    def start_refresh_thread(session)
      Thread.new do
        loop do
          sleep @seconds
          session.client.command(refreshSessions: [session.session_id])
          @refresh_count += 1
        end
      end
    end
  end
end
