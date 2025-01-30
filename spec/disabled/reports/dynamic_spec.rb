# frozen_string_literal: true

require "spec_helper"
require "reports/dynamic"

RSpec.xdescribe Reports::Dynamic do
  let(:base_hol) { "holdings" }
  let(:base_com) { "commitments" }
  let(:base_hti) { "ht_items" }
  let(:base_ocn) { "ocn_resolutions" }
  let(:log_t) { 0 } # set to 1 for all the logs

  let(:dec1) { ["holdings.ocn"] }
  let(:dec2) { ["holdings.ocn", "holdings.local_id"] }
  let(:res1) { [{"holdings.organization" => "umich"}] }
  let(:res2) { [{"holdings.organization" => "umich"}, {"holdings.status" => "CH"}] }

  let(:min_params) { {base: base_hol, decorations: dec1, log_toggle: log_t} }
  let(:basic_params) { {base: base_hol, decorations: dec1, restrictions: res1, log_toggle: log_t} }
  let(:dynamic_ok) { described_class.new(**min_params) }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  describe "#initialize" do
    it "does not raise if given proper args" do
      expect { described_class.new(**basic_params) }.to_not raise_error
    end
  end

  describe "#validate_clusterable" do
    it "accepts all the clusterable classes and nothing else" do
      [base_hol, base_com, base_hti, base_ocn].each do |c|
        expect(dynamic_ok.validate_clusterable(c)).to eq c
      end
      expect { dynamic_ok.validate_clusterable("") }.to raise_error ArgumentError
    end
  end

  describe "#decorations" do
    it "requires 1+ (valid) decorations" do
      expect { dynamic_ok.add_decorations([]) }.to raise_error ArgumentError
      expect { dynamic_ok.add_decorations(["foo"]) }.to raise_error ArgumentError
      expect { dynamic_ok.add_decorations(dec1) }.to_not raise_error
    end
    it "allows multiple decorations" do
      expect { dynamic_ok.add_decorations(dec2) }.to_not raise_error
    end
  end

  describe "#restrictions" do
    it "allows empty restrictions" do
      expect {
        described_class.new(base: base_hol, decorations: dec1, restrictions: [])
      }.to_not raise_error
    end
    it "allows any valid model-field as a restriction" do
      expect { described_class.new(**basic_params) }.to_not raise_error
    end
    it "rejects an invalid model-field as a restriction" do
      # this should raise an ArgumentError that matches rx
      rx = /\(organization\) is not a field in Clusterable::HtItem/
      expect {
        described_class.new(
          base: base_hol,
          decorations: dec1,
          restrictions: [{"ht_items.organization" => "umich"}]
        )
      }.to raise_error ArgumentError, rx
    end
  end

  describe "#header" do
    it "is based on @decorations" do
      params = min_params
      expect(described_class.new(**params).header).to eq "ocn"

      params[:decorations] << "holdings.local_id"
      expect(described_class.new(**params).header).to eq "ocn\tlocal_id"
    end
  end

  describe "#records" do
    it "returns matching records" do
      1.upto(3).each do |i|
        cluster_tap_save(
          build(:holding, organization: "umich", ocn: i),
          build(:holding, organization: "smu", ocn: i)
        )
      end
      expect(described_class.new(**basic_params).records.count).to eq 3
    end
    it "can combine multiple restrictions" do
      # Load 3 holdings, all umich, different status
      cluster_tap_save(
        build(:holding, organization: "umich", status: "CH"),
        build(:holding, organization: "umich", status: "LM"),
        build(:holding, organization: "umich", status: "WD")
      )

      # if only restricting on org, get all 3
      expect(
        described_class.new(
          base: base_hol,
          decorations: dec1,
          restrictions: [{"holdings.organization" => "umich"}]
        ).records.count
      ).to eq 3

      # if restricting on org AND status, only get the one
      expect(
        described_class.new(
          base: base_hol,
          decorations: dec1,
          restrictions: [{"holdings.organization" => "umich"}, {"holdings.status" => "CH"}]
        ).records.count
      ).to eq 1
    end
    it "can query by (almost) any field on any clusterable" do
      # Lots of setup here.
      # Test querying by all fields, individually, on a Clusterable::Holding
      # Each test case also has a :fail that will cause the query to return 0.
      test_cases = [
        {
          clusterable: build(:holding, local_id: "it"),
          params: {base: "holdings", decorations: ["holdings.ocn"]},
          fail: {"holdings.local_id" => "not it"}
        },
        {
          clusterable: build(:commitment, local_id: "it"),
          params: {base: "commitments", decorations: ["commitments.ocn"]},
          fail: {"commitments.local_id" => "not it"}
        },
        {
          clusterable: build(:ht_item, item_id: "it"),
          params: {base: "ht_items", decorations: ["ht_items.item_id"]},
          fail: {"ht_items.item_id" => "not it"}
        }
      ]

      test_cases.each do |test_case|
        clusterable = test_case[:clusterable]
        params = test_case[:params]
        base = params[:base]
        Cluster.collection.find.delete_many # the before(:all) wont trigger here
        built_clusterable = cluster_tap_save(clusterable)
        built_clusterable.first.fields.each do |field_name, _cruft|
          # _id is not a real field so let's not query by it.
          next if field_name == "_id"
          base_field = [base, ".", field_name].join
          # THIS is where I think casting needs to come in.
          field_val = built_clusterable.first.send(field_name)

          # OK after all this setup, 2 tests.
          # First, a positive test. Can we find 1 clusterable if we search for each of its fields?
          restrictions = [{base_field => field_val}]
          report = described_class.new(
            base: params[:base],
            decorations: params[:decorations],
            restrictions: restrictions
          )
          expect(report.records.count).to eq 1

          # Second, a negative (but valid) test.
          # If we add another restriction to the query (:fail),
          # that we know is going to result in zero records, does it really?
          report = described_class.new(
            base: params[:base],
            decorations: params[:decorations],
            restrictions: restrictions << test_case[:fail]
          )
          expect(report.records.count).to eq 0
        end
      end
    end
  end

  describe "outputs" do
    it "auto-generates its own output dir" do
      dir = dynamic_ok.output_dir
      expect(Dir.exist?(dir)).to be true
    end
    it "auto-generates its own file when running" do
      # So, does not exist at first, but the path is known
      file = dynamic_ok.output_file
      expect(File.exist?(file)).to be false
      cluster_tap_save(build(:holding))
      dynamic_ok.run
      # We ran, path is the same, file now exists.
      expect(File.exist?(file)).to be true
    end
  end

  describe "#run" do
    it "puts it all together" do
      # Make 10 holdings and run {base: holdings, decorations: holdings.ocn},
      # expect a file with 1 header line (ocn), and 10 output lines.
      buf = []
      num_holdings = 10
      1.upto(num_holdings) do |ocn|
        buf << build(:holding, ocn: ocn)
      end
      cluster_tap_save(*buf)
      dynamic_ok.run
      outf = dynamic_ok.output_file
      expect(File.exist?(outf)).to be true
      lines = File.read(outf).split("\n")
      header = lines.shift
      expect(header).to eq "ocn"
      expect(lines.count).to eq num_holdings
    end
  end
end
