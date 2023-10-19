require "spec_helper"
require "utils/report_output"

RSpec.describe Utils::ReportOutput do
  let(:report_name) { "foo" }
  let(:ext) { ".bar" }
  let(:default_ext) { ".tsv" }
  let(:report_output) { described_class.new(report_name, ext) }
  it "has working attr_readers" do
    expect(report_output.report_name).to eq report_name
    expect(report_output.ext).to eq ext
  end
  it "has a default ext: .tsv" do
    expect(described_class.new(report_name).ext).to eq default_ext
  end
  it "makes dir if missing" do
    # dir_path only gives the path ...
    # dir makes the path if missing,
    dir_path = report_output.dir_path
    expect(Dir.exist?(dir_path)).to be false
    report_output.dir
    expect(Dir.exist?(dir_path)).to be true
  end
  it "gives a predictable singleton-ish file" do
    f1 = report_output.file
    f2 = report_output.file
    expect(f1).to eq f2
    # Grab a new object if you want a new file
    report_output2 = described_class.new(report_name, ext)
    f3 = report_output.file
    f4 = report_output2.file # this one will be different
    expect(f2).to eq f3
    # by power of transitivity we know f1-f3 are the same,
    # we only expect f4 to be different
    expect(f3).to_not eq f4
  end
  it "gives a predictable singleton-ish id" do
    id1 = report_output.id
    id2 = report_output.id
    expect(id1).to eq id2
    # Grab a new object if you want a new id
    report_output2 = described_class.new(report_name, ext)
    id3 = report_output.id
    id4 = report_output2.id # this one will be different
    expect(id2).to eq id3
    # by power of transitivity we know id1-id3 are the same,
    # we only expect id4 to be different
    expect(id3).to_not eq id4
  end
  it "gives readable/writable handle" do
    # write a string to a write-handle
    write_handle = report_output.handle("w")
    str = "It was a dark and stormy #{report_output.id} ..."
    write_handle.puts(str)
    write_handle.close
    # and then read that string with a read-handle
    read_handle = report_output.handle("r")
    lines = read_handle.read.split("\n")
    read_handle.close
    expect(lines.count).to eq 1
    expect(lines).to eq [str]
  end
end
