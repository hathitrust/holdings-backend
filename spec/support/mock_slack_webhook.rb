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
