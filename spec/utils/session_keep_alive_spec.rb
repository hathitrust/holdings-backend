# frozen_string_literal: true

require "spec_helper"
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

  # KeepAlive doesn't fix CursorNotFound
  context "with using KeepAlive to prevent Cursor loss on a long running process" do
    before(:each) do
      Cluster.each(&:delete)
      create(:cluster)
      create(:cluster)
    end

    # Fails as expected
    it "raises CursorNotFound after 10 minutes", :slow do
      expect(Cluster.count).to eq(2)
      expect { Cluster.batch_size(1).no_timeout.each { |_c| sleep(660) } }
        .to raise_error(Mongo::Error::OperationFailure, /CursorNotFound/)
    end

    # This fails
    xit "Keep Alive prevents the CursorNotFound error" do
      ska = described_class.new(60)
      expect do
        ska.run do
          Cluster.batch_size(1).no_timeout.each { |_c| sleep(660) }
        end
      end.not_to raise_error
    end
  end

  # Reducing batch_size DOES prevent CursorNotFound
  context "with reducing batch size to prevent Cursor loss" do
    before(:each) do
      Cluster.each(&:delete)
      # default batch size is 1000
      2000.times { |x| create(:cluster, ocns: [x]) }
    end

    # true, CursorNotFound
    it "fails when a batch takes longer than 10 minutes", :slow do
      expect { Cluster.batch_size(250).no_timeout.each { |_c| sleep(3) } }
        .to raise_error(Mongo::Error::OperationFailure, /CursorNotFound/)
    end

    # true
    it "does not fail if we reduce batch size to keep time under 10 minutes", :slow do
      expect { Cluster.batch_size(100).no_timeout.each { |_c| sleep(3) } }.not_to raise_error
    end
  end

  # max_time_ms doesn't fix CursorNotFound
  context "with changing maxTimeMS in order to prevent Cursor loss" do
    before(:each) do
      Cluster.each(&:delete)
      create(:cluster)
      create(:cluster)
    end

    # Does not fail as expected. maxTimeMS doesn't mean what I think it means?
    xit "fails when a batch takes longer than the max time" do
      expect { Cluster.max_time_ms(1000).each { |_c| sleep(3) } }
        .to raise_error(Mongo::Error::OperationFailure, /CursorNotFound/)
    end

    # And this fails
    xit "does not fail if we set max_time_ms to 0" do
      expect { Cluster.max_time_ms(0).batch_size(1).each { |_c| sleep(660) } }.not_to raise_error
    end
  end
end
