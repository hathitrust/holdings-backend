# frozen_string_literal: true

require "spec_helper"
require "hathifile_manager"

RSpec.describe HathifileManager do
  describe "#try_load" do
    let(:loading_flag) { double(:loading_flag) }
    let(:hathifile_factory) { double(:hathifile_factory) }
    let(:loader) do
      described_class.new(hathifile_factory: hathifile_factory,
                          last_loaded: last_loaded,
                          loading_flag: loading_flag)
    end

    context "when there are no new files" do
      let(:last_loaded) { Date.today }

      it "doesn't set the loading flag" do
        expect(loading_flag).not_to receive(:with_lock)
      end
    end

    context "when there is one new file" do
      let(:last_loaded) { Date.today - 1 }

      it "tries to load the new file" do
        todays_file = double(:todays)

        allow(hathifile_factory).to receive(:call)
          .with(Date.today)
          .and_return(todays_file)

        allow(loading_flag).to receive(:with_lock).and_yield

        expect(todays_file).to receive(:load).and_return(true)

        loader.try_load
      end
    end

    context "when there are two new files" do
      let(:last_loaded) { Date.today - 2 }

      let(:yesterdays_file) { double(:yesterdays) }
      let(:todays_file) { double(:todays) }

      before(:each) do
        allow(loading_flag).to receive(:with_lock).and_yield

        allow(hathifile_factory).to receive(:call)
          .with(Date.today - 1)
          .and_return(yesterdays_file)

        allow(hathifile_factory).to receive(:call)
          .with(Date.today)
          .and_return(todays_file)
      end

      it "tries to load each new file" do
        expect(yesterdays_file).to receive(:load).and_return(true)
        expect(todays_file).to receive(:load).and_return(true)

        loader.try_load
      end

      it "aborts if one file fails" do
        allow(yesterdays_file).to receive(:load)
          .and_return(false)

        expect(todays_file).not_to receive(:load)

        loader.try_load
      end
    end
  end
end
