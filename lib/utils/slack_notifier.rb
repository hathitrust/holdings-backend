# frozen_string_literal: true

require "faraday"
require "services"

module Utils
  module SlackNotifier
    # url kwarg allows injection in tests; defaults to Settings for production use
    def self.post(message, url: Settings.slack_webhook_url)
      return unless url

      Faraday.post(url, {text: message}.to_json, "Content-Type" => "application/json")
    rescue => e
      Services.logger.error "SlackNotifier failed: #{e.message}"
    end
  end
end
