# frozen_string_literal: true

require "settings"

module Utils
  # Outputs the given message to Slack, using the given endpoint
  #
  # Intended for use with Logger, e.g:
  #
  # Usage: Logger.new(SlackWriter.new("http://whatever"), level: Logger::INFO)
  class SlackWriter
    require "faraday"

    def initialize(endpoint)
      @endpoint = endpoint
    end

    def write(msg)
      Faraday.post(@endpoint, { text: msg }.to_json,
                   "Content-Type" => "application/json")
    end

    def close; end
  end
end
