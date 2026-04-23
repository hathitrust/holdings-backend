# frozen_string_literal: true

require "utils/slack_notifier"
require "spec_helper"

# Unit tests for the unconfigured (no webhook URL) and network failure cases —
# cheaper here than wiring them through the full scrub pipeline in the integration spec.
RSpec.describe Utils::SlackNotifier do
  let(:webhook_url) { "https://hooks.slack.com/services/TEST/WEBHOOK/URL" }
  let(:message) { "Holdings load complete for *umich* (`mon`) — 6 records loaded, 0 old records removed." }

  describe ".post" do
    context "when slack_webhook_url is configured" do
      it "POSTs the message as JSON to the webhook URL" do
        stub = stub_request(:post, webhook_url)
          .with(
            body: {text: message}.to_json,
            headers: {"Content-Type" => "application/json"}
          )
          .to_return(status: 200)

        # url kwarg bypasses Settings/ENV; see SlackNotifier.post signature
        described_class.post(message, url: webhook_url)

        expect(stub).to have_been_requested
      end
    end

    context "when slack_webhook_url is nil" do
      it "makes no HTTP request" do
        described_class.post(message, url: nil)

        expect(a_request(:any, //)).not_to have_been_made
      end
    end

    context "when a network error occurs" do
      it "logs the error and does not raise" do
        stub_request(:post, webhook_url).to_raise(Faraday::ConnectionFailed.new("connection refused"))

        expect(Services.logger).to receive(:error).with(a_string_matching(/SlackNotifier/))
        expect { described_class.post(message, url: webhook_url) }.not_to raise_error
      end
    end
  end
end
