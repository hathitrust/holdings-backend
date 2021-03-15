require 'member_holding'
require "custom_errors"
require 'json'


RSpec.describe MemberHolding do
  let(:test_data) { __dir__ + "/../testdata" }
  let(:ok_min_hed) {{"oclc"=>0, "local_id"=>1}}
  let(:ok_min_str) {"123\t456"}
  let(:ok_min_hold) {MemberHolding.new(ok_min_hed)}

  let(:ok_max_hed) {
    {
      "oclc"      => 0,
      "local_id"  => 1,
      "status"    => 2,
      "condition" => 3,
      "enumchron" => 4,
      "govdoc"    => 5
    }
  }
  let(:ok_max_str) {"123\tb456\tCH\tBRT\tv.1, 2020\t0"}
  let(:ok_max_hold){MemberHolding.new(ok_max_hed)}

  let(:bad_min_str) {"FAIL_ME\t456"}
  
  it "creates a MemberHolding (min fields example)" do
    expect(ok_min_hold).to be_a(MemberHolding)
  end

  it "creates a MemberHolding (max fields example)" do
    expect(ok_max_hold).to be_a(MemberHolding)
  end
  
  it "parses a string (min example)" do
    expect(ok_min_hold.parse_str(ok_min_str)).to be(true)
  end
  
  it "parses a string (max example)" do
    expect(ok_max_hold.parse_str(ok_max_str)).to be(true)
  end

  it "sees no violations when parsing an ok string (min example)" do
    expect(ok_min_hold.violations).to eq([])
  end

  it "sees no violations when parsing an ok string (max example)" do
    expect(ok_max_hold.violations).to eq([])
  end

  it "produces valid json (min example)" do
    ok_min_hold.parse_str(ok_min_str)
    json_str = ok_min_hold.to_json
    expect(JSON.parse(json_str)).to be_a(Hash)
  end

  it "produces valid json (max example)" do
    ok_max_hold.parse_str(ok_max_str)
    json_str = ok_max_hold.to_json
    expect(JSON.parse(json_str)).to be_a(Hash)
  end

  it "raises an error if given a bad col type" do
    expect{ok_min_hold.parse_str("")}.to raise_error(ColValError)
  end
  
  it "raises an error if given a bad col val" do
    expect{ok_min_hold.parse_str(bad_min_str)}.to raise_error(ColValError)
  end
  
end
