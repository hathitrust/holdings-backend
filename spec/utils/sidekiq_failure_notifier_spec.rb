# frozen_string_literal: true

require "utils/sidekiq_failure_notifier"
require "spec_helper"

RSpec.describe Utils::SidekiqFailureNotifier do
  include_context "with mocked slack alerts endpoint"

  let(:error) { RuntimeError.new("disk full") }

  describe ".failure_message" do
    it "includes will retry notice, job class, args, error class, and message" do
      job = {"class" => "Jobs::Load::Holdings", "args" => ["/data/umich.ndj"], "retry_count" => 1}
      msg = described_class.failure_message(job, error)
      expect(msg).to include("Sidekiq job failed (will retry)")
      expect(msg).to include("Jobs::Load::Holdings")
      expect(msg).to include("/data/umich.ndj")
      expect(msg).to include("RuntimeError")
      expect(msg).to include("disk full")
    end
  end

  describe ".death_message" do
    it "includes no more retries notice, job class, args, error class, and message" do
      job = {"class" => "Jobs::Load::Holdings", "args" => ["/data/umich.ndj"], "retry_count" => 24}
      msg = described_class.death_message(job, error)
      expect(msg).to include("Sidekiq job failed (no more retries)")
      expect(msg).to include("Jobs::Load::Holdings")
      expect(msg).to include("/data/umich.ndj")
      expect(msg).to include("RuntimeError")
      expect(msg).to include("disk full")
    end
  end

  describe ".on_error" do
    def run_handler(job)
      described_class.on_error(error, {job: job})
    end

    it "does not post to Slack on 1st attempt (retry_count nil)" do
      run_handler({"class" => "Jobs::Common", "retry_count" => nil})
      expect(a_request(:post, alerts_webhook_url)).not_to have_been_made
    end

    it "does not post to Slack on 2nd attempt (retry_count 0)" do
      run_handler({"class" => "Jobs::Common", "retry_count" => 0})
      expect(a_request(:post, alerts_webhook_url)).not_to have_been_made
    end

    it "posts to Slack on 3rd attempt (retry_count 1)" do
      stub = stub_request(:post, alerts_webhook_url).to_return(status: 200)
      run_handler({"class" => "Jobs::Common", "retry_count" => 1})
      expect(stub).to have_been_requested.once
    end

    it "does not post to Slack on retries between the two thresholds (retry_count 2)" do
      run_handler({"class" => "Jobs::Common", "retry_count" => 2})
      expect(a_request(:post, alerts_webhook_url)).not_to have_been_made
    end

    it "posts to Slack on 7th attempt (retry_count 5)" do
      stub = stub_request(:post, alerts_webhook_url).to_return(status: 200)
      run_handler({"class" => "Jobs::Common", "retry_count" => 5})
      expect(stub).to have_been_requested.once
    end

    it "does not post to Slack on retries after the second threshold (retry_count 6+)" do
      run_handler({"class" => "Jobs::Common", "retry_count" => 6})
      expect(a_request(:post, alerts_webhook_url)).not_to have_been_made
    end

    it "does not post to Slack when ctx has no job" do
      described_class.on_error(error, {})
      expect(a_request(:post, alerts_webhook_url)).not_to have_been_made
    end

    context "when slack_alerts_webhook_url is nil" do
      around do |example|
        old = Settings.slack_alerts_webhook_url
        Settings.slack_alerts_webhook_url = nil
        example.run
        Settings.slack_alerts_webhook_url = old
      end

      it "makes no HTTP request" do
        run_handler({"class" => "Jobs::Common", "retry_count" => 1})
        expect(a_request(:any, //)).not_to have_been_made
      end
    end
  end
end
