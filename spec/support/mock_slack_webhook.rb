# frozen_string_literal: true

RSpec.shared_context "with mocked slack API endpoint" do
  let(:webhook_url) { "https://hooks.slack.invalid/services/TEST/WEBHOOK" }

  def stub_slack_webhook(body)
    stub_request(:post, webhook_url)
      .with(body: body)
      .to_return(status: 200)
  end

  around(:each) do |example|
    old_webhook_url = Settings.slack_webhook_url
    Settings.slack_webhook_url = webhook_url
    stub_request(:post, webhook_url).to_return(status: 200)
    example.run
    Settings.slack_webhook_url = old_webhook_url
  end
end

RSpec.shared_context "with mocked slack alerts endpoint" do
  let(:alerts_webhook_url) { "https://hooks.slack.invalid/services/TEST/ALERTS_WEBHOOK" }

  def stub_slack_alerts_webhook(body)
    stub_request(:post, alerts_webhook_url)
      .with(body: body)
      .to_return(status: 200)
  end

  around(:each) do |example|
    old_alerts_webhook_url = Settings.slack_alerts_webhook_url
    Settings.slack_alerts_webhook_url = alerts_webhook_url
    stub_request(:post, alerts_webhook_url).to_return(status: 200)
    example.run
    Settings.slack_alerts_webhook_url = old_alerts_webhook_url
  end
end
