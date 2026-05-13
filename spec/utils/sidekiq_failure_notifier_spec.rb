# frozen_string_literal: true

require "utils/sidekiq_failure_notifier"
require "spec_helper"

RSpec.describe Utils::SidekiqFailureNotifier do
  include_context "with mocked slack alerts endpoint"

  let(:error) { RuntimeError.new("disk full") }

  describe "NOTIFY_AT_RETRY_COUNT" do
    it "is 1 (triggers on the 3rd failure)" do
      expect(described_class::NOTIFY_AT_RETRY_COUNT).to eq 1
    end
  end

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

  describe "Middleware" do
    subject(:middleware) { described_class::Middleware.new }

    def run_middleware(job, &blk)
      middleware.call(nil, job, "default", &blk)
    rescue RuntimeError
      # expected re-raise
    end

    it "always re-raises the exception" do
      job = {"class" => "Jobs::Common", "retry_count" => 1}
      expect {
        middleware.call(nil, job, "default") { raise error }
      }.to raise_error(RuntimeError, "disk full")
    end

    it "does not post to Slack on 1st attempt (retry_count nil)" do
      run_middleware({"class" => "Jobs::Common", "retry_count" => nil}) { raise error }
      expect(a_request(:post, alerts_webhook_url)).not_to have_been_made
    end

    it "does not post to Slack on 2nd attempt (retry_count 0)" do
      run_middleware({"class" => "Jobs::Common", "retry_count" => 0}) { raise error }
      expect(a_request(:post, alerts_webhook_url)).not_to have_been_made
    end

    it "posts to Slack exactly once on 3rd attempt (retry_count 1)" do
      stub = stub_request(:post, alerts_webhook_url).to_return(status: 200)
      run_middleware({"class" => "Jobs::Common", "retry_count" => 1}) { raise error }
      expect(stub).to have_been_requested.once
    end

    it "does not post to Slack on subsequent retries (retry_count 2+)" do
      run_middleware({"class" => "Jobs::Common", "retry_count" => 2}) { raise error }
      expect(a_request(:post, alerts_webhook_url)).not_to have_been_made
    end

    it "does not post to Slack when the job succeeds" do
      middleware.call(nil, {"class" => "Jobs::Common", "retry_count" => 1}, "default") { nil }
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
        run_middleware({"class" => "Jobs::Common", "retry_count" => 1}) { raise error }
        expect(a_request(:any, //)).not_to have_been_made
      end
    end
  end
end
