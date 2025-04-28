# frozen_string_literal: true

require "rack/test"
require "api/holdings_api"

APP = Rack::Builder.parse_file("bin/api_config.ru")

RSpec.describe "HoldingsApi" do
  include Rack::Test::Methods
  include_context "with tables for holdings"

  let(:app) { APP }
  let(:base_url) { "http://localhost:4567" }
  # ht_item 1 is an spm with a single ocn
  let(:item_id_1) { "test.123" }
  let(:ocn) { 123 }
  let(:htitem_1) { build(:ht_item, :spm, item_id: item_id_1, ocns: [ocn], billing_entity: "umich") }

  # ht_item 2 is an mpm
  let(:item_id_2) { "test.123456" }
  let(:ocn2) { [123, 456] }
  let(:htitem_2) { build(:ht_item, :mpm, item_id: item_id_2, ocns: ocn2, enum_chron: "v.1-5 (1901-1905)") }

  # ht_item 3 is an spm with 3 ocns
  let(:item_id_3) { "test.123456789" }
  let(:ocns) { [123, 456, 789] }
  let(:htitem_3) { build(:ht_item, :spm, item_id: item_id_3, ocns: ocns) }

  let(:slashy_ht_item_id) { "aeu.ark:/13960/t04x6jk58" }
  let(:slashy_ht_item) { build(:ht_item, :spm, item_id: slashy_ht_item_id, ocns: [ocn], billing_entity: "ualberta") }

  def make_call(call)
    get "#{base_url}/#{call}"
  end

  def url_template(page, **kwargs)
    params = []
    kwargs.each do |k, v|
      params << "#{k}=#{v}"
    end
    "#{page}?" + params.join("&")
  end

  def v1(url)
    "v1/" + url
  end

  def parse_body(call)
    make_call(call)
    # Useful debug that includes call and response:
    # puts "#{call} ==> #{last_response.body}"
    JSON.parse(last_response.body)
  end

  describe "/ping" do
    it "ping-pongs" do
      make_call(v1("ping"))
      expect(last_response.body).to eq "pong"
      expect(last_response.status).to eq 200
    end
  end

  describe "invalid route" do
    it "responds with a 404" do
      make_call("invalid/route")
      expect(last_response.status).to eq 404
    end
  end

  describe "missing arguments -> #404 & application_error message" do
    it "missing organization" do
      load_test_data(htitem_1)
      response = parse_body(v1(url_template("item_access", item_id: item_id_1)))
      expect(response["application_error"]).to eq "missing required param: organization"
      expect(last_response.status).to eq 404
    end
    it "missing item_id" do
      load_test_data(htitem_1)
      response = parse_body(v1(url_template("item_access", organization: "umich")))
      expect(response["application_error"]).to eq "missing required param: item_id"
      expect(last_response.status).to eq 404
    end
    it "missing both" do
      load_test_data(htitem_1)
      response = parse_body(v1(url_template("item_access")))
      expect(response["application_error"]).to eq "missing required param: organization; missing required param: item_id"
      expect(last_response.status).to eq 404
    end
  end

  describe "/item_access" do
    it "returns an error message if there is no matching htitem" do
      response = parse_body(v1(url_template("item_access", item_id: item_id_1, organization: "umich")))
      expect(response["application_error"]).to eq "no matching data"
      expect(last_response.status).to eq 404
    end
    it "returns 0 if no holdings (and not depositor)" do
      load_test_data(htitem_1)
      response = parse_body(v1(url_template("item_access", item_id: item_id_1, organization: "upenn")))
      expect(response["ocns"]).to eq [ocn]
      expect(response["copy_count"]).to eq 0
    end
    it "handles ht_items with slashes" do
      load_test_data(slashy_ht_item)
      call = v1(url_template("item_access", item_id: slashy_ht_item_id, organization: "umich"))
      response = parse_body(call)
      expect(response["copy_count"]).to eq 0
    end
    it "simplest positive case with 1 item, 1 ocn, 1 org, 1 holding" do
      load_test_data(
        htitem_1,
        build(:holding, organization: "umich", ocn: ocn)
      )
      response = parse_body(v1(url_template("item_access", item_id: item_id_1, organization: "umich")))
      expect(response["ocns"]).to eq [ocn]
      expect(response["copy_count"]).to eq 1
    end
    it "positive case with 1 item, 1 ocn, 1 org, 3 holdings" do
      load_test_data(
        htitem_1,
        build(:holding, organization: "umich", ocn: ocn),
        build(:holding, organization: "umich", ocn: ocn),
        build(:holding, organization: "umich", ocn: ocn)
      )
      response = parse_body(v1(url_template("item_access", item_id: item_id_1, organization: "umich")))
      expect(response["ocns"]).to eq [ocn]
      expect(response["copy_count"]).to eq 3
    end
    it "positive case with 1 item, 1 ocn, 2 orgs, 3 holdings (split umich 1, smu 2)" do
      load_test_data(
        htitem_1,
        build(:holding, organization: "umich", ocn: ocn),
        build(:holding, organization: "smu", ocn: ocn),
        build(:holding, organization: "smu", ocn: ocn)
      )
      # umich, 1 holding
      response = parse_body(v1(url_template("item_access", item_id: item_id_1, organization: "umich")))
      expect(response["ocns"]).to eq [ocn]
      expect(response["copy_count"]).to eq 1
      # smu, 2 holdings
      response = parse_body(v1(url_template("item_access", item_id: item_id_1, organization: "smu")))
      expect(response["ocns"]).to eq [ocn]
      expect(response["copy_count"]).to eq 2
    end
    it "concatenates the ocns to make a lock_id" do
      load_test_data(
        htitem_3,
        build(:holding, organization: "umich", ocn: ocn)
      )
      response = parse_body(v1(url_template("item_access", item_id: item_id_3, organization: "smu")))
      expect(response["ocns"]).to eq [123, 456, 789]
    end
    it "gets the counts for holdings with ocns matching the item" do
      load_test_data(
        htitem_3,
        build(:holding, organization: "umich", ocn: 123),
        build(:holding, organization: "umich", ocn: 456),
        build(:holding, organization: "umich", ocn: 789),
        build(:holding, organization: "umich", ocn: 999999999, local_id: "not matching")
      )
      response = parse_body(v1(url_template("item_access", item_id: item_id_3, organization: "umich")))
      expect(response["copy_count"]).to eq 3
    end
    it "returns an empty n_enum for spm" do
      load_test_data(htitem_1)
      response = parse_body(v1(url_template("item_access", item_id: item_id_1, organization: "umich")))
      expect(response["n_enum"]).to eq ""
    end
    it "returns non-empty n_enum for mpm" do
      load_test_data(htitem_2)
      response = parse_body(v1(url_template("item_access", item_id: item_id_2, organization: "umich")))
      expect(response["n_enum"]).to eq "1-5"
    end
    it "returns format:spm for an item in a spm cluster" do
      load_test_data(htitem_1)
      response = parse_body(v1(url_template("item_access", item_id: item_id_1, organization: "umich")))
      expect(response["format"]).to eq "spm"
    end
    it "returns format:mpm for an item in a mpm cluster" do
      load_test_data(htitem_2)
      response = parse_body(v1(url_template("item_access", item_id: item_id_2, organization: "umich")))
      expect(response["format"]).to eq "mpm"
    end
    it "correctly identifies mpms as not held when not held" do
      ht1 = build(:ht_item, enum_chron: "v.1", billing_entity: "umich")
      ht2 = build(:ht_item, enum_chron: "v.2", ocns: ht1.ocns, billing_entity: "umich")
      holding = build(:holding, enum_chron: "v.1", ocn: ht1.ocns.first, organization: "upenn")
      load_test_data(ht1, ht2, holding)

      # as set up above, upenn's holdings matches on ht1 but not on ht2 (different enumchron)
      response = parse_body(v1(url_template("item_access", organization: holding.organization, item_id: ht1.item_id)))
      expect(response["copy_count"]).to eq 1
      response = parse_body(v1(url_template("item_access", organization: holding.organization, item_id: ht2.item_id)))
      expect(response["copy_count"]).to eq 0
    end
    it "treats an empty holdings enum_chron as a wildcard, matches all" do
      ht1 = build(:ht_item, enum_chron: "v.1", billing_entity: "umich")
      ht2 = build(:ht_item, enum_chron: "v.2", ocns: ht1.ocns, billing_entity: "umich")
      holding = build(:holding, enum_chron: "", ocn: ht1.ocns.first, organization: "upenn")
      load_test_data(ht1, ht2, holding)

      # as set up above, upenn's holdings (empty enumchron) matches on ht1 both ht2
      response = parse_body(v1(url_template("item_access", organization: holding.organization, item_id: ht1.item_id)))
      expect(response["copy_count"]).to eq 1
      response = parse_body(v1(url_template("item_access", organization: holding.organization, item_id: ht2.item_id)))
      expect(response["copy_count"]).to eq 1
    end
  end

  describe "v1/item_held_by" do
    it "returns an application error if the item_id does not match an ht_item" do
      response = parse_body(v1(url_template("item_held_by", item_id: item_id_1)))
      expect(response["application_error"]).to eq "no matching data"
    end
    it "returns an array with the submitter if no organization has reported holdings matching ht_item" do
      load_test_data(htitem_1)
      response = parse_body(v1(url_template("item_held_by", item_id: item_id_1)))
      expect(response["organizations"]).to eq ["umich"]
    end
    it "returns an array with the submitter if only submitter has reported holdings matching ht_item" do
      load_test_data(htitem_1, build(:holding, organization: "umich", ocn: 123))
      response = parse_body(v1(url_template("item_held_by", item_id: item_id_1)))
      expect(response["organizations"]).to eq ["umich"]
    end
    it "returns an array with all organizations with holdings matching ht_item" do
      load_test_data(
        htitem_1,
        build(:holding, organization: "umich", ocn: ocn),
        build(:holding, organization: "smu", ocn: ocn)
      )
      response = parse_body(v1(url_template("item_held_by", item_id: item_id_1, organization: "umich")))
      expect(response["organizations"].sort).to eq ["smu", "umich"]
    end
  end

  describe "v1/record_held_by" do
    # not mocking solr here, but we do want the data in the same format
    include_context "with mocked solr response"

    it "given a record with ocns and items, returns holdings for all items in the record" do
      ht1 = build(:ht_item, enum_chron: "v.1", billing_entity: "umich")
      ht2 = build(:ht_item, ht_bib_key: ht1.ht_bib_key, enum_chron: "v.2", 
                  ocns: ht1.ocns, billing_entity: "umich")

      holding = build(:holding, enum_chron: "v.1", ocn: ht1.ocns.first, organization: "upenn")
      load_test_data(ht1, ht2, holding)

      # solr record in the format traject should send it to us
      solr_record_no_holdings = JSON.parse(solr_response_for(ht1,ht2))["response"]["docs"][0].to_json
      require "debug"
      debugger

      post v1(url_template("record_held_by")), solr_record_no_holdings, 'Content-Type' => 'application/json'

      response = JSON.parse(last_response.body)

      ht1_response = response.find { |i| i["item_id"] = ht1.item_id }
      ht2_response = response.find { |i| i["item_id"] = ht2.item_id }

      expect(ht1_response["organizations"]).to contain_exactly("umich","upenn")
      expect(ht2_response["organizations"]).to contain_exactly("umich")
    end
  end
end
