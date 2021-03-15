require "member_holding_file"
require "custom_errors"

RSpec.describe MemberHoldingFile do
  let(:test_data) { __dir__ + "/../testdata" }

  # Vars for tests expected to pass, prefix "ok_"
  let(:ok_mem) {"umich"}
  let(:ok_fn)  {"umich_mono_full_20201230_corrected.tsv"}
  let(:ok_mhf) {MemberHoldingFile.new(ok_fn)}
  let(:ok_itype) {"mono"}
  let(:ok_col_map) {{"oclc"=>0, "local_id"=>1}}
  
  let(:ok_header_mhf) {
    MemberHoldingFile.new(
      "#{test_data}/haverford_mono_full_20200101_header.tsv"
    )
  }
  
  # Vars for tests expected to fail, prefix "bad_"
  let(:bad_mem) {""}
  let(:bad_fn)  {"FAIL ME PLEASE"}
  let(:bad_mhf) {MemberHoldingFile.new(bad_fn)}

  # each badness = !+
  let(:bad_fn_1) {"!!!!!_mono_full_20201230.tsv"} # bad member_id
  let(:bad_fn_2) {"umich_!!!!_full_20201230.tsv"} # bad item_type
  let(:bad_fn_3) {"umich_mono_!!!!_20201230.tsv"} # bad update type
  let(:bad_fn_4) {"umich_mono_full_!!!!!!!!.tsv"} # bad date
  let(:bad_fn_5) {"umich_mono_full_20201230.!!!"} # bad extension

  # file headers
  let(:ok_hed_min) {["oclc", "local_id"]}
  let(:ok_hed_mul) {%w[oclc local_id status condition enumchron govdoc]}
  
  it "finds member_id in filename" do
    expect(ok_mhf.get_member_id_from_filename(ok_fn)).to eq(ok_mem)
    expect(ok_mhf.get_member_id_from_filename()).to eq(ok_mem)
  end

  it "raises error if no member_id in filename" do
    expect{ok_mhf.get_member_id_from_filename("")}.to raise_error(FileNameError)
    expect{ok_mhf.get_member_id_from_filename(nil)}.to raise_error(FileNameError)
  end

  it "finds item type in filename" do
    expect(ok_mhf.get_item_type_from_filename()).to eq(ok_itype)
  end

  it "raises error if no item_type in filename" do
    expect{bad_mhf.get_item_type_from_filename()}.to raise_error(FileNameError)
  end

  it "checks a whole filename" do
    expect(ok_mhf.valid_filename?).to be(true)
    expect(bad_mhf.valid_filename?).to be(false)
  end

  it "rejects a bad filename for the right reason" do
    expect(MemberHoldingFile.new(bad_fn_1).valid_filename?).to be(false)
    expect(MemberHoldingFile.new(bad_fn_2).valid_filename?).to be(false)
    expect(MemberHoldingFile.new(bad_fn_3).valid_filename?).to be(false)
    expect(MemberHoldingFile.new(bad_fn_4).valid_filename?).to be(false)
    expect(MemberHoldingFile.new(bad_fn_5).valid_filename?).to be(false)
  end
  
  it "it turns a line into a MemberHolding" do
    expect(
      ok_header_mhf.item_from_line("123\t123", ok_col_map)
    ).to be_a(MemberHolding)

    expect(
      ok_header_mhf.item_from_line("123\t123", ok_col_map).violations
    ).to eq([])
  end
  
  it "can read a file" do
    expect{ok_header_mhf.parse}.not_to raise_error
  end

  it "cannot read a bad file" do
    # This should fail for any number of reasons,
    # so all we're catching/expecting is StandardError
    expect {bad_mhf.parse}.to raise_error(StandardError)
  end
  
end
