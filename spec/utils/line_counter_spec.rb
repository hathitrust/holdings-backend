# frozen_string_literal: true

require "utils/line_counter"
require "spec_helper"

# Because when declared as a `let` it does not work in the after(:all) hook.
test_dir = "/tmp/line_counter_test"
RSpec.describe Utils::LineCounter do
  before(:each) do
    FileUtils.rm_rf(test_dir)
    FileUtils.mkdir_p(test_dir)
  end

  after(:all) do
    FileUtils.rm_rf(test_dir)
  end

  let(:null_path) { "/tmp/i/do/not/exist" }
  let(:empty_file) { File.join(test_dir, "empty_file") }
  let(:ten_line_file) { File.join(test_dir, "ten_line_file") }
  let(:gzip_file) { File.join(test_dir, "gzip_file.gz") }

  it "raises if path does not point to a file" do
    expect { described_class.new(null_path) }.to raise_error IOError
  end

  it "counts zero lines in an empty file" do
    FileUtils.touch(empty_file)
    expect(described_class.new(empty_file).count_lines).to eq 0
  end

  it "gets the proper IO class for a given file" do
    FileUtils.touch ten_line_file
    FileUtils.touch gzip_file
    expect(described_class.new(ten_line_file).io).to eq File
    expect(described_class.new(gzip_file).io).to eq Zlib::GzipReader
  end

  it "counts as many lines as there are in a file" do
    File.open(ten_line_file, "w") do |file|
      1.upto(10).each do |i|
        file.puts i
      end
    end
    expect(described_class.new(ten_line_file).count_lines).to eq 10
  end

  it "counts lines in gzipped lines too" do
    system(%(echo -e "1\n2\n3" | gzip > #{gzip_file}))
    expect(described_class.new(gzip_file).count_lines).to eq 3
  end
end
