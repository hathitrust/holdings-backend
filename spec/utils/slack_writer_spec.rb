# frozen_string_literal: true

require "spec_helper"
require "utils/slack_writer"
require "faker"

RSpec.describe Utils::SlackWriter do
  before(:each) do
    stub_request(:post, Settings.slack_endpoint)
      .with(body: /{"text":".*"}/,
           headers: { "Content-Type" => "application/json" })
  end

  let(:writer) { described_class.new(Settings.slack_endpoint) }

  describe "#write" do
    it "posts the given message to the configured endpoint" do
      message = Faker::Lorem.sentence
      writer.write(message)

      expect(WebMock).to have_requested(:post, Settings.slack_endpoint)
        .with(body: /#{message}/)
    end
  end

  describe "#close" do
    it "doesn't raise" do
      expect { writer.close }.not_to raise_exception
    end
  end
end
