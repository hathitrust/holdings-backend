# frozen_string_literal: true

require "spec_helper"
require "enum_chron"

class DummyRecord
  #  include Mongoid::Document
  #  include EnumChron
  #  field :enum_chron
  #  field :n_enum
  #  field :n_chron
  #  field :n_enum_chron
end

RSpec.xdescribe EnumChron do
  let(:rec_w_ec) { DummyRecord.new(enum_chron: "1 aug") }
  let(:rec_w_empty_ec) { DummyRecord.new(enum_chron: "") }
  let(:rec_wo_ec) { DummyRecord.new }

  it "uses EnumChronParser to set n_chron, n_enum, and n_enum_chron" do
    expect(rec_w_ec.n_enum).to eq("1")
    expect(rec_w_ec.n_chron).to eq("aug")
    expect(rec_w_ec.n_enum_chron).to eq("1\taug")
  end

  it "replaces tabs in enum and chron so we can use it as delimiter" do
    rec_w_ec = DummyRecord.new(enum_chron: "vol\t1\tAug\t5")
    expect(rec_w_ec.n_enum_chron).to eq("vol:1\tAug 5")
  end

  it "sets n_chron, n_enum, n_enum_chron to empty string if empty enumchron" do
    expect(rec_w_empty_ec.n_chron).to eq("")
    expect(rec_w_empty_ec.n_enum).to eq("")
    expect(rec_w_empty_ec.n_enum_chron).to eq("")
  end

  it "sets n_chron, n_enum, n_enum_chron to empty string if nil enumchron" do
    expect(rec_wo_ec.n_chron).to eq("")
    expect(rec_wo_ec.n_enum).to eq("")
    expect(rec_wo_ec.n_enum_chron).to eq("")
  end
end
