# frozen_string_literal: true

require "utils/multi_logger"
require "logger"
require "spec_helper"
require "faker"

RSpec.describe Utils::MultiLogger do
  def fake_dev
    double(:writer, write: true, close: true)
  end

  let(:dev1) { fake_dev }
  let(:dev2) { fake_dev }

  it "can be constructed with multiple Loggers" do
    expect(described_class.new(Logger.new(dev1), Logger.new(dev2))).not_to be_nil
  end

  it "outputs formatted messages to each configured logger" do
    logger = described_class.new(Logger.new(dev1), Logger.new(dev2))

    message = Faker::Lorem.sentence

    expect(dev1).to receive(:write).with(/ERROR.*#{message}/)
    expect(dev2).to receive(:write).with(/ERROR.*#{message}/)

    logger.error(message)
  end

  it "forwards messages regardless of severity" do
    fake_logger = double(:fake_logger, add: true)
    logger = described_class.new(fake_logger)
    logger.level = Logger::ERROR

    expect(fake_logger).to receive(:add)

    logger.debug(Faker::Lorem.sentence)
  end
end
