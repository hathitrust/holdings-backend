# frozen_string_literal: true

require "spec_helper"
require "file_mutex"
require "fileutils"

RSpec.describe FileMutex do
  let(:path) { "/tmp/file_mutex" }
  let(:mutex) { described_class.new(path) }

  before(:each) { FileUtils.rm_f(path) }

  describe "#with_lock" do
    context "when the file exists" do
      it "raises MutexHeldException" do
        FileUtils.touch(path)
        expect { mutex.with_lock {} }.to raise_exception(MutexHeldException)
      end
    end

    context "when the file does not exist" do
      it "runs the given block" do
        expect { |b| mutex.with_lock(&b) }.to yield_control
      end

      it "creates the file before running the block" do
        mutex.with_lock do
          expect(File).to exist(path)
        end
      end

      it "removes the file after running the block" do
        mutex.with_lock {}
        expect(File).not_to exist(path)
      end

      it "removes the file after running the block if the block raises an exception" do
        begin
          mutex.with_lock { raise "an exception" }
        rescue RuntimeError
          nil
        end

        expect(File).not_to exist(path)
      end
    end
  end
end
