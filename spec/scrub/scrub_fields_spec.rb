# frozen_string_literal: true

require "scrub/scrub_fields"
require "services"

RSpec.describe Scrub::ScrubFields do
  let(:sf) { described_class.new }

  it "keeps tally of what was rejected & why" do
    # Make sure the tally for status("foo") is 0.
    rej_foo = "status:foo".to_sym
    Services.scrub_stats[rej_foo] = 0
    # Call status("foo") and check that it incr'ed.
    sf.status("foo")
    expect(Services.scrub_stats[rej_foo]).to eq(1)
  end

  it "returns a simple OCN as an array" do
    expect(sf.ocn("1")).to eq([1])
    expect(sf.ocn("1,2")).to eq([1, 2])
  end

  it "returns empty array if given no or bad OCNs" do
    expect(sf.ocn("")).to eq([])
    expect(sf.ocn("0")).to eq([])
    expect(sf.ocn(nil)).to eq([])
  end

  it "dedupes OCNs" do
    expect(sf.ocn("1,1,1")).to eq([1])
    expect(sf.ocn("1,ocn1,(ocolc)1")).to eq([1])
  end

  it "rejects an OCN candidate for being nil/empty" do
    expect { sf.try_to_reject_ocn(nil) }.to throw_symbol(:rejected_value)
    expect { sf.try_to_reject_ocn("") }.to throw_symbol(:rejected_value)
  end

  it "rejects an OCN candidate for having exponential notation" do
    expect { sf.try_to_reject_ocn("3.226E+13") }.to throw_symbol(:rejected_value)
  end

  it "rejects an OCN candidate for having a mix of [a-z] and [0-9]" do
    expect { sf.try_to_reject_ocn("1a2") }.to throw_symbol(:rejected_value)
    expect { sf.try_to_reject_ocn("a1b") }.to throw_symbol(:rejected_value)
  end

  it "accepts allowed OCN prefixes" do
    expect(sf.ocn("oclc1,ocm2,ocn3,ocolc4")).to eq([1, 2, 3, 4])
    expect(sf.ocn("(oclc)1,(ocm)2,(ocn)3,(ocolc)4")).to eq([1, 2, 3, 4])
  end

  it "rejects disallowed OCN prefixes" do
    # of course, the universe of disallowed prefixes is huge, so...
    expect(sf.ocn("foo1,(bar)1")).to eq([])
  end

  it "rejects an OCN if it's too big" do
    expect { sf.try_to_reject_ocn("9999999999999") }.to throw_symbol(:rejected_value)
  end

  it "returns empty array for a nil local_id" do
    expect(sf.local_id(nil)).to eq([])
  end

  it "rejects a local_id that is too long" do
    expect(sf.local_id("9" * 100)).to eq([])
  end

  it "accepts any decent local_id" do
    expect(sf.local_id("i1234567890")).to eq(["i1234567890"])
  end

  it "allows but trims spaces in local_id" do
    expect(sf.local_id("  i1234567890  ")).to eq(["i1234567890"])
  end

  it "rejects bad ISSNs" do
    expect(sf.issn("1")).to eq([""])
    expect(sf.issn("123456789")).to eq([""])
    expect(sf.issn("12345678X")).to eq([""])
  end

  it "accepts good ISSNs" do
    expect(sf.issn("1234-5678")).to eq(["1234-5678"])
    expect(sf.issn("12345678")).to eq(["12345678"])
    expect(sf.issn("1234567X")).to eq(["1234567X"])
  end

  it "filters out bad ISSNs, leaving good ones" do
    expect(sf.issn("1234567X, foo")).to eq(["1234567X"])
  end

  it "parses enumchrons" do
    # enum_chron_spec.rb has its own tests,
    # so let's not go into detail here
    expect(sf.enumchron("vol 1, 1999")).to eq(["vol:1", "1999"])
  end

  it "accepts allowed status" do
    expect(sf.status("CH")).to eq(["CH"])
    expect(sf.status("LM")).to eq(["LM"])
    expect(sf.status("WD")).to eq(["WD"])
  end

  it "rejects bad status" do
    expect(sf.status("BRT")).to eq([])
    expect(sf.status("X")).to eq([])
    expect(sf.status("")).to eq([])
  end

  it "accepts allowed condition" do
    expect(sf.condition("BRT")).to eq(["BRT"])
  end

  it "rejects bad condition" do
    expect(sf.condition("CH")).to eq([])
    expect(sf.condition("X")).to eq([])
    expect(sf.condition("")).to eq([])
  end

  it "accepts allowed govdoc" do
    expect(sf.govdoc("1")).to eq(["1"])
    expect(sf.govdoc("0")).to eq(["0"])
  end

  it "rejects bad govdoc" do
    expect(sf.govdoc("CH")).to eq([])
    expect(sf.govdoc("X")).to eq([])
    expect(sf.govdoc("")).to eq([])
  end
end
