# frozen_string_literal: true

require "faraday"
require "services"

module Utils
  module SlackNotifier
    def self.post(message)
      webhook_url = Settings.slack_webhook_url
      return unless webhook_url

      Faraday.post(webhook_url, {text: message}.to_json, "Content-Type" => "application/json")
    rescue => e
      Services.logger.error "SlackNotifier failed: #{e.message}"
    end
  end
end
