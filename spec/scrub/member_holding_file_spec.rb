# frozen_string_literal: true

require "scrub/member_holding_file"
require "custom_errors"

RSpec.describe Scrub::MemberHoldingFile do
  let(:test_data) { __dir__ + "/../../testdata" }

  # Vars for tests expected to pass, prefix "ok_"
  let(:ok_mem) { "umich" }
  let(:ok_fn)  { "umich_mono_full_20201230_corrected.tsv" }
  let(:ok_mhf) { described_class.new(ok_fn) }
  let(:ok_header_mhf) do
    described_class.new(
      "#{test_data}/haverford_mono_full_20200101_header.tsv"
    )
  end

  let(:ok_itype) { "mono" }
  let(:ok_col_map) { { "oclc"=>0, "local_id"=>1 } }

  # Vars for tests expected to fail, prefix "bad_"
  let(:bad_mem) { "" }
  let(:bad_fn)  { "FAIL ME PLEASE" }
  let(:bad_mhf) { described_class.new(bad_fn) }

  # file headers
  let(:ok_hed_min) { ["oclc", "local_id"] }
  let(:ok_hed_mul) { ["oclc", "local_id", "status", "condition", "enumchron", "govdoc"] }

  it "finds member_id in filename" do
    expect(ok_mhf.member_id_from_filename(ok_fn)).to eq(ok_mem)
    expect(ok_mhf.member_id_from_filename).to eq(ok_mem)
  end

  it "raises error if no member_id in filename" do
    expect { ok_mhf.member_id_from_filename("") }.to raise_error(FileNameError)
    expect { ok_mhf.member_id_from_filename(nil) }.to raise_error(FileNameError)
  end

  it "finds item type in filename" do
    expect(ok_mhf.item_type_from_filename).to eq(ok_itype)
  end

  it "raises error if no item_type in filename" do
    expect { bad_mhf.item_type_from_filename }.to raise_error(FileNameError)
  end

  it "checks a whole filename" do
    expect(ok_mhf.valid_filename?).to be(true)
  end

  context "with bad filenames" do
    let(:bad_fn_1) { "!!!!!_mono_full_20201230.tsv" } # bad member_id
    let(:bad_fn_2) { "umich_!!!!_full_20201230.tsv" } # bad item_type
    let(:bad_fn_3) { "umich_mono_!!!!_20201230.tsv" } # bad update type
    let(:bad_fn_4) { "umich_mono_full_!!!!!!!!.tsv" } # bad date
    let(:bad_fn_5) { "umich_mono_full_20201230.!!!" } # bad extension

    it "Raises an error if it can't figure out member_id or item_type" do
      expect { described_class.new(bad_fn_1).valid_filename? }.to raise_error(FileNameError)
      expect { described_class.new(bad_fn_2).valid_filename? }.to raise_error(FileNameError)
    end

    it "rejects a bad filename for the right reason" do
      expect(described_class.new(bad_fn_3).valid_filename?).to be(false)
      expect(described_class.new(bad_fn_4).valid_filename?).to be(false)
      expect(described_class.new(bad_fn_5).valid_filename?).to be(false)
    end
  end

  it "turns a line into an array of MemberHolding(s)" do
    value = ok_header_mhf.item_from_line("123\t123", ok_col_map)
    expect(value).to be_a(Array)
    expect(value.first).to be_a(Scrub::MemberHolding)
    expect(value.first.violations).to eq([])
  end

  it "explodes a line with multiple ocns into one MemberHolding per ocn" do
    value = ok_header_mhf.item_from_line("1,2,3\t123", ok_col_map)
    expect(value).to be_a(Array)
    expect(value.size).to be(3)
  end

  it "can read a file and yield MemberHolding records" do
    expect { ok_header_mhf.parse {|record| } }.not_to raise_error

    expect  do
      ok_header_mhf.parse do |record|
        unless record.is_a?(Scrub::MemberHolding)
          raise "yielded something else"
        end
      end
    end.not_to raise_error
  end

  it "cannot read a bad file" do
    # This should fail for any number of reasons,
    # so all we're catching/expecting is StandardError
    expect { bad_mhf.parse }.to raise_error(StandardError)
  end
end
