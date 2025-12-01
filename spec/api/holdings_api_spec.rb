# frozen_string_literal: true

require "rack/test"
require "api/holdings_api"

APP = Rack::Builder.parse_file("bin/api_config.ru")

RSpec.describe HoldingsAPI do
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
  let(:enum_chron) { "v.1-5 (1901-1905)" }
  let(:n_enum) { "1-5" }
  let(:htitem_2) { build(:ht_item, :mpm, item_id: item_id_2, ocns: ocn2, enum_chron: enum_chron) }

  # ht_item 3 is an spm with 3 ocns
  let(:item_id_3) { "test.123456789" }
  let(:ocns) { [123, 456, 789] }
  let(:htitem_3) { build(:ht_item, :spm, item_id: item_id_3, ocns: ocns) }

  let(:slashy_ht_item_id) { "aeu.ark:/13960/t04x6jk58" }
  let(:slashy_ht_item) { build(:ht_item, :spm, item_id: slashy_ht_item_id, ocns: [ocn], billing_entity: "ualberta") }

  def url_template(page, **kwargs)
    params = []
    # Assume version 1 for this spec, a new version should probably have its own spec file.
    version = 1

    kwargs.each do |k, v|
      params << "#{k}=#{v}"
    end

    if params.any?
      "v#{version}/#{page}?" + params.join("&")
    else
      "v#{version}/#{page}"
    end
  end

  def make_call(call)
    get "#{base_url}/#{call}"
  end

  def parse_response(...)
    url = url_template(...)
    make_call(url)
    response = last_response.body
    # puts "#{url} ==> #{response}"
    JSON.parse(response)
  end

  describe "/ping" do
    it "ping-pongs" do
      make_call(url_template("ping"))
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
      response = parse_response("item_access", item_id: item_id_1)
      expect(response["application_error"]).to eq "missing required param: organization"
      expect(last_response.status).to eq 404
    end

    it "missing item_id" do
      load_test_data(htitem_1)
      response = parse_response("item_access", organization: "umich")
      expect(response["application_error"]).to eq "missing required param: item_id"
      expect(last_response.status).to eq 404
    end

    it "missing both" do
      load_test_data(htitem_1)
      response = parse_response("item_access")
      expect(response["application_error"]).to eq "missing required param: organization; missing required param: item_id"
      expect(last_response.status).to eq 404
    end
  end

  describe "v1/item_access" do
    it "returns an error message if there is no matching htitem" do
      response = parse_response("item_access", item_id: item_id_1, organization: "umich")
      expect(response["application_error"]).to eq "no matching data"
      expect(last_response.status).to eq 404
    end

    it "returns application error if item exists but org does not exist" do
      load_test_data(htitem_1)
      response = parse_response("item_access", item_id: item_id_1, organization: "does-not-exist")
      expect(response["application_error"]).to eq "no matching data"
      expect(last_response.status).to eq 404
    end

    it "returns 0 if no holdings (and not depositor)" do
      load_test_data(htitem_1)
      response = parse_response("item_access", item_id: item_id_1, organization: "upenn")
      expect(response["ocns"]).to eq [ocn]
      expect(response["copy_count"]).to eq 0
    end

    it "handles ht_items with slashes" do
      load_test_data(slashy_ht_item)
      response = parse_response("item_access", item_id: slashy_ht_item_id, organization: "umich")
      expect(response["copy_count"]).to eq 0
    end

    it "simplest positive case with 1 item, 1 ocn, 1 org, 1 holding" do
      load_test_data(
        htitem_1,
        build(:holding, organization: "umich", ocn: ocn)
      )
      response = parse_response("item_access", item_id: item_id_1, organization: "umich")
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
      response = parse_response("item_access", item_id: item_id_1, organization: "umich")
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
      response = parse_response("item_access", item_id: item_id_1, organization: "umich")
      expect(response["ocns"]).to eq [ocn]
      expect(response["copy_count"]).to eq 1
      # smu, 2 holdings
      response = parse_response("item_access", item_id: item_id_1, organization: "smu")
      expect(response["ocns"]).to eq [ocn]
      expect(response["copy_count"]).to eq 2
    end

    it "concatenates the ocns to make a lock_id" do
      load_test_data(
        htitem_3,
        build(:holding, organization: "umich", ocn: ocn)
      )
      response = parse_response("item_access", item_id: item_id_3, organization: "smu")
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
      response = parse_response("item_access", item_id: item_id_3, organization: "umich")
      expect(response["copy_count"]).to eq 3
    end

    it "returns an empty n_enum for spm" do
      load_test_data(htitem_1)
      response = parse_response("item_access", item_id: item_id_1, organization: "umich")
      expect(response["n_enum"]).to eq ""
    end

    it "returns non-empty n_enum for mpm" do
      load_test_data(htitem_2)
      response = parse_response("item_access", item_id: item_id_2, organization: "umich")
      expect(response["n_enum"]).to eq n_enum
    end

    it "returns format:spm for an item in a spm cluster" do
      load_test_data(htitem_1)
      response = parse_response("item_access", item_id: item_id_1, organization: "umich")
      expect(response["format"]).to eq "spm"
    end

    it "returns format:mpm for an item in a mpm cluster" do
      load_test_data(htitem_2)
      response = parse_response("item_access", item_id: item_id_2, organization: "umich")
      expect(response["format"]).to eq "mpm"
    end

    # Brittle test?
    it "correctly identifies mpms as not held when not held" do
      ht1 = build(:ht_item, enum_chron: "v.1", billing_entity: "umich")
      ht2 = build(:ht_item, enum_chron: "v.2", ocns: ht1.ocns, billing_entity: "umich")
      holding = build(:holding, enum_chron: "v.1", ocn: ht1.ocns.first, organization: "upenn")
      load_test_data(ht1, ht2, holding)

      # as set up above, upenn's holdings matches on ht1 but not on ht2 (different enumchron)
      response = parse_response("item_access", organization: holding.organization, item_id: ht1.item_id)
      expect(response["copy_count"]).to eq 1
      response = parse_response("item_access", organization: holding.organization, item_id: ht2.item_id)
      expect(response["copy_count"]).to eq 0
    end

    it "treats an empty holdings enum_chron as a wildcard, matches all" do
      ht1 = build(:ht_item, enum_chron: "v.1", billing_entity: "umich")
      ht2 = build(:ht_item, enum_chron: "v.2", ocns: ht1.ocns, billing_entity: "umich")
      holding = build(:holding, enum_chron: "", ocn: ht1.ocns.first, organization: "upenn")
      load_test_data(ht1, ht2, holding)

      # as set up above, upenn's holdings (empty enumchron) matches on ht1 both ht2
      response = parse_response("item_access", organization: holding.organization, item_id: ht1.item_id)
      expect(response["copy_count"]).to eq 1
      response = parse_response("item_access", organization: holding.organization, item_id: ht2.item_id)
      expect(response["copy_count"]).to eq 1
    end

    it "brlm_count indicates number of BRT/LM holdings by organization, spm" do
      load_test_data(
        htitem_1,
        build(:holding, organization: "umich", ocn: ocn, status: nil, condition: "")
      )

      # brlm_count defaults to 0
      # holdings with empty status/condition do not count towards brlm_count
      response = parse_response("item_access", item_id: item_id_1, organization: "umich")
      expect(response["brlm_count"]).to eq 0

      # holdings with condition: "BRT" count towards brlm_count
      load_test_data(build(:holding, organization: "umich", ocn: ocn, condition: "BRT"))
      response = parse_response("item_access", item_id: item_id_1, organization: "umich")
      expect(response["brlm_count"]).to eq 1

      # holdings with status: LM count towards brlm_count
      load_test_data(build(:holding, organization: "umich", ocn: ocn, status: "LM"))
      response = parse_response("item_access", item_id: item_id_1, organization: "umich")
      expect(response["brlm_count"]).to eq 2
    end

    it "brlm_count indicates number of BRT/LM holdings by organization, mpm" do
      # Setting all of these test holdings to be BRT, since we are already testing
      # the BRT/LM functionality in the spm-tests.
      # These here tests are more about the matchiness of the enum_chrons.
      holding_args = {
        organization: "umich",
        ocn: ocn2.first,
        status: nil,
        condition: "BRT",
        mono_multi_serial: "mpm",
        enum_chron: ""
      }

      item_access_args = {
        item_id: item_id_2,
        organization: "umich"
      }

      holding_empty = build(:holding, **holding_args)
      holding_matching = build(:holding, **holding_args, enum_chron: enum_chron)
      holding_nonmatching = build(:holding, **holding_args, enum_chron: "999-1001")
      load_test_data(htitem_2)

      load_test_data(holding_empty)
      # empty enum_chron matches
      response = parse_response("item_access", **item_access_args)
      expect(response["brlm_count"]).to eq 1

      load_test_data(holding_matching)
      # matching enum_chron matches
      response = parse_response("item_access", **item_access_args)
      expect(response["brlm_count"]).to eq 2

      load_test_data(holding_nonmatching)
      # non-matching enum_chron does not match
      response = parse_response("item_access", **item_access_args)
      expect(response["brlm_count"]).to eq 2
    end

    it "currently_held indicates copy_count - (wd + lm)" do
      load_test_data(htitem_1)
      item_access_args = {item_id: item_id_1, organization: "umich"}

      # Add a WD, see copy_count++, non_withdrawn_count==0
      load_test_data(build(:holding, organization: "umich", ocn: ocn, status: "WD"))
      response = parse_response("item_access", **item_access_args)
      expect(response["copy_count"]).to eq 1
      expect(response["currently_held_count"]).to eq 0

      # Add a CH, see copy_count++ and non_withdrawn_count++
      load_test_data(build(:holding, organization: "umich", ocn: ocn, status: "CH"))
      response = parse_response("item_access", **item_access_args)
      expect(response["copy_count"]).to eq 2
      expect(response["currently_held_count"]).to eq 1
    end

    it "identifies items held by mapped-to institutions as held" do
      # stanford has mapto_instid = stanford_mapped
      # when we query for instid = stanford_mapped, we should get holdings for stanford
      load_test_data(
        htitem_1,
        build(:holding, organization: "stanford", ocn: ocn)
      )
      response = parse_response("item_access", organization: "stanford_mapped", item_id: htitem_1.item_id)
      expect(response["copy_count"]).to eq 1

      # ualberta is also mapped to stanford_mapped in spec/fixtures/organizations.rb
      # so any ocns held by stanford and/or ualberta count towards stanford_mapped
      load_test_data(build(:holding, organization: "ualberta", ocn: ocn))
      response = parse_response("item_access", organization: "stanford_mapped", item_id: htitem_1.item_id)
      expect(response["copy_count"]).to eq 2

      # umich is not mapped to stanford_mapped, so their holdings should not count
      load_test_data(build(:holding, organization: "umich", ocn: ocn))
      response = parse_response("item_access", organization: "stanford_mapped", item_id: htitem_1.item_id)
      expect(response["copy_count"]).to eq 2
    end
  end

  describe "v1/item_held_by" do
    it "returns an application error if the item_id does not match an ht_item" do
      response = parse_response("item_held_by", item_id: item_id_1)
      expect(response["application_error"]).to eq "no matching data"
    end

    it "returns an array with the submitter if no organization has reported holdings matching ht_item" do
      load_test_data(htitem_1)
      response = parse_response("item_held_by", item_id: item_id_1)
      expect(response["organizations"]).to eq ["umich"]
    end

    it "returns an array with the submitter if only submitter has reported holdings matching ht_item" do
      load_test_data(htitem_1, build(:holding, organization: "umich", ocn: 123))
      response = parse_response("item_held_by", item_id: item_id_1)
      expect(response["organizations"]).to eq ["umich"]
    end

    it "returns an array with all organizations with holdings matching ht_item" do
      load_test_data(
        htitem_1,
        build(:holding, organization: "umich", ocn: ocn),
        build(:holding, organization: "smu", ocn: ocn)
      )
      response = parse_response("item_held_by", item_id: item_id_1)
      expect(response["organizations"].sort).to eq ["smu", "umich"]
    end
  end

  describe "v1/record_held_by" do
    # not mocking solr here, but we do want the data in the same format
    include_context "with mocked solr response"

    it "given a record with ocns and items, returns holdings for all items in the record" do
      ocn = 123
      ht1 = build(:ht_item, enum_chron: "v.1", bib_fmt: "BK", ocns: [ocn], billing_entity: "umich")
      ht2 = build(:ht_item, ht_bib_key: ht1.ht_bib_key, enum_chron: "v.2", bib_fmt: "BK", ocns: [ocn], billing_entity: "umich")
      holding = build(:holding, enum_chron: "v.1", ocn: ocn, organization: "upenn")
      load_test_data(ht1, ht2, holding)

      # solr record in the format traject should send it to us
      solr_record_no_holdings = solr_docs_for(ht1, ht2)[0].to_json

      post base_url + "/" + url_template("record_held_by"), solr_record_no_holdings, "CONTENT_TYPE" => "application/json"

      response = JSON.parse(last_response.body)

      ht1_response = response.find { |i| i["item_id"] == ht1.item_id }
      ht2_response = response.find { |i| i["item_id"] == ht2.item_id }

      expect(ht1_response["organizations"]).to contain_exactly("umich", "upenn")
      expect(ht2_response["organizations"]).to contain_exactly("umich")
    end
  end

  describe "v1/item_held_by?constraint=brlm" do
    it "returns an application error if given an invalid constraint" do
      load_test_data(htitem_1)
      response = parse_response("item_held_by", item_id: item_id_1, constraint: "foo")
      expect(response["application_error"]).to eq "Invalid constraint."
    end

    it "reports nothing if there are no holdings" do
      load_test_data(htitem_1)
      response = parse_response("item_held_by", item_id: item_id_1, constraint: "brlm")
      expect(response["organizations"]).to eq []
    end

    it "reports nothing if all holdings are status:CH & condition:''" do
      load_test_data(htitem_1)
      load_test_data(build(:holding, organization: "a", ocn: htitem_1.ocns.first, status: "CH", condition: ""))
      response = parse_response("item_held_by", item_id: item_id_1, constraint: "brlm")
      expect(response["organizations"]).to eq []
    end

    it "reports nothing if all holdings are status:WD & condition:''" do
      load_test_data(htitem_1)
      load_test_data(build(:holding, organization: "a", ocn: htitem_1.ocns.first, status: "WD", condition: ""))
      response = parse_response("item_held_by", item_id: item_id_1, constraint: "brlm")
      expect(response["organizations"]).to eq []
    end

    it "reports the organizations with LM holdings" do
      load_test_data(htitem_1)
      load_test_data(build(:holding, organization: "a", ocn: htitem_1.ocns.first, status: "LM", condition: ""))
      load_test_data(build(:holding, organization: "b", ocn: htitem_1.ocns.first, status: nil, condition: ""))
      response = parse_response("item_held_by", item_id: item_id_1, constraint: "brlm")
      expect(response["organizations"]).to eq ["a"]
    end

    it "reports the organizations with BRT holdings" do
      load_test_data(htitem_1)
      load_test_data(build(:holding, organization: "a", ocn: htitem_1.ocns.first, status: nil, condition: "BRT"))
      load_test_data(build(:holding, organization: "b", ocn: htitem_1.ocns.first, status: nil, condition: ""))
      response = parse_response("item_held_by", item_id: item_id_1, constraint: "brlm")
      expect(response["organizations"]).to eq ["a"]
    end

    it "reports the organizations with BRT+LM holdings" do
      load_test_data(htitem_1)
      load_test_data(build(:holding, organization: "a", ocn: htitem_1.ocns.first, status: "LM", condition: "BRT"))
      load_test_data(build(:holding, organization: "b", ocn: htitem_1.ocns.first, status: nil, condition: ""))
      response = parse_response("item_held_by", item_id: item_id_1, constraint: "brlm")
      expect(response["organizations"]).to eq ["a"]
    end

    it "reports all the relevant organizations" do
      load_test_data(htitem_1)
      load_test_data(build(:holding, organization: "a", ocn: htitem_1.ocns.first, status: nil, condition: "BRT"))
      load_test_data(build(:holding, organization: "b", ocn: htitem_1.ocns.first, status: "LM", condition: ""))
      load_test_data(build(:holding, organization: "c", ocn: htitem_1.ocns.first, status: "LM", condition: "BRT"))
      load_test_data(build(:holding, organization: "d", ocn: htitem_1.ocns.first, status: "CH", condition: "BRT"))
      response = parse_response("item_held_by", item_id: item_id_1, constraint: "brlm")
      expect(response["organizations"]).to eq ["a", "b", "c", "d"]
    end
  end
end
