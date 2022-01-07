# frozen_string_literal: true

require "utils/session_keep_alive"

# These tests require some amount of sleep, but since sleeps are
# below 1s duration I chose to not tag these as :slow. Feel free
# to change if tests are starting to take too long.

RSpec.describe Utils::SessionKeepAlive do
  it "refreshes 0 times if the duration is below than the refresh rate" do
    keeper = described_class.new(0.5)
    expect(keeper.seconds).to eq(0.5)
    expect(keeper.refresh_count).to eq(0)
    keeper.run do
      sleep 0.01
    end
    expect(keeper.refresh_count).to eq(0)
  end

  it "refreshes 2 times if the duration is ~2 times the refresh rate" do
    keeper = described_class.new(0.1)
    expect(keeper.seconds).to eq(0.1)
    expect(keeper.refresh_count).to eq(0)
    keeper.run do
      sleep 0.25
    end
    expect(keeper.refresh_count).to eq(2)
  end

  it "kills the thread when done" do
    keeper = described_class.new(1)
    expect(keeper.refresher_thread).to eq nil
    keeper.run do
      sleep 0.01
      expect(keeper.refresher_thread.alive?).to be true
    end
    sleep 0.001 # or thread won't have time to update
    expect(keeper.refresher_thread.alive?).to be false
  end

  xit "does not have a test that refreshSessions prevents session/cursor death" do
    # todo
  end
end
