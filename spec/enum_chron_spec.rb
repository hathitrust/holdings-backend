# frozen_string_literal: true

require "spec_helper"
require "enum_chron"

class DummyRecord
  include Mongoid::Document
  include EnumChron
  attr_accessor :enum_chron, :n_enum, :n_chron

end

RSpec.describe EnumChron do
  let(:rec_w_ec) { DummyRecord.new(enum_chron: "1 aug") }
  let(:rec_w_empty_ec) { DummyRecord.new(enum_chron: "") }
  let(:rec_wo_ec) { DummyRecord.new }

  it "uses EnumChronParser to set n_chron and n_enum" do
    expect(rec_w_ec.n_enum).to eq("1")
    expect(rec_w_ec.n_chron).to eq("aug")
  end

  it "sets n_chron and n_enum to empty string if empty enumchron" do
    expect(rec_w_empty_ec.n_chron).to eq("")
    expect(rec_w_empty_ec.n_enum).to eq("")
  end

  it "sets n_chron and n_enum to empty string if nil enumchron" do
    expect(rec_wo_ec.n_chron).to eq("")
    expect(rec_wo_ec.n_enum).to eq("")
  end
end
