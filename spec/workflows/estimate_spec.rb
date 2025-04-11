require "spec_helper"
require "workflows/estimate"

RSpec.describe Workflows::Estimate do
  include_context "with tables for holdings"
  include_context "with mocked solr response"

  # two records; one with a PD item, one with an IC item
  let(:ht_allow) { build(:ht_item, rights: "pd") }
  let(:ht_deny) { build(:ht_item, rights: "ic") }

  before(:each) do
    Settings.target_cost = 20
    load_test_data(ht_allow, ht_deny)
  end

  describe Workflows::Estimate::Writer do
    let(:writer) { described_class.new(working_directory: nil, ocn_file: nil) }

    describe "#cost_report" do
      it "creates an empty CR for target_cost reasons" do
        expect(writer.cost_report.target_cost).to eq(20)
        # two volumes in ht_items, so 10 each
        expect(writer.cost_report.cost_per_volume).to eq(10)
      end
    end

    context "with sample data" do
      # the file name is used to construct the output file, but it shouldn't be
      # read in this step
      let(:ocn_file) { "/nonexistent/ocnfile.txt" }

      before(:each) do
        File.open(File.join(ENV["TEST_TMP"], "ocn_count.estimate.json"), "w") do |f|
          f.puts({
            "ocns_total" => 4,
            "ocns_matched" => 2
          }.to_json)
        end

        File.open(File.join(ENV["TEST_TMP"], "test1.estimate.json"), "w") do |f|
          f.puts({
            "items_matched" => 1,
            "items_ic" => 1,
            "items_pd" => 0,
            "h_share" => 0.5
          }.to_json)
        end

        File.open(File.join(ENV["TEST_TMP"], "test2.estimate.json"), "w") do |f|
          f.puts({
            "items_matched" => 1,
            "items_ic" => 0,
            "items_pd" => 1,
            "h_share" => 0
          }.to_json)
        end
      end

      it "sums input json files to produce output in the expected format" do
        described_class.new(working_directory: ENV["TEST_TMP"], ocn_file: ocn_file).run

        estimate_file = File.join(Settings.estimates_path, "ocnfile-estimate-#{Date.today}.txt")

        expect(File.read(estimate_file)).to eq <<~EOT
          Total Estimated IC Cost: $5.00
          In all, we received 4 distinct OCLC numbers.
          Of those distinct OCLC numbers, 2 (50.0%) match items in
          HathiTrust, corresponding to 2 HathiTrust items.
          Of those items, 1 (50.0%) are in the public domain,
          1 (50.0%) are in copyright.
        EOT
      end
    end
  end

  describe Workflows::Estimate::Analyzer do
    let(:test_records) { File.join(ENV["TEST_TMP"], record_filename) }
    let(:output_json) { JSON.parse(File.read(test_records + ".estimate.json")) }

    before(:each) do
      FileUtils.cp(fixture(record_filename), ENV["TEST_TMP"])
    end

    context "with two items, one pd and one ic" do
      let(:record_filename) { "records_for_estimate.ndj" }

      it "outputs number of items matched" do
        described_class.new(test_records).run
        expect(output_json["items_matched"]).to eq(2)
      end

      it "outputs number of pd items matched" do
        described_class.new(test_records).run
        expect(output_json["items_pd"]).to eq(1)
      end

      it "outputs number of ic items matched" do
        described_class.new(test_records).run
        expect(output_json["items_ic"]).to eq(1)
      end

      it "outputs h_share_total" do
        described_class.new(test_records).run
        # the contributor gets the other half of the IC item
        expect(output_json["h_share"]).to eq(0.5)
      end
    end

    context "one with icus item" do
      let(:record_filename) { "icus_item.ndj" }

      it "outputs icus items as pd" do
        FileUtils.cp(fixture("icus_item.ndj"), ENV["TEST_TMP"])
        described_class.new(File.join(ENV["TEST_TMP"], "icus_item.ndj")).run
        expect(output_json["items_pd"]).to eq(1)
      end
    end
  end

  describe Workflows::Estimate::DataSource do
    let(:ocn_file) { File.join(ENV["TEST_TMP"], "ocnfile") }
    let(:output) { File.join(ENV["TEST_TMP"], "records.out") }
    let(:ocn_count) { File.join(ENV["TEST_TMP"], "ocn_count.estimate.json") }

    let(:data_source) { described_class.new(ocn_file: ocn_file) }

    describe "#dump_records" do
      before(:each) { File.write(ocn_file, ocns.join("\n")) }

      context "with four ocns and two items" do
        let(:ocns) { [1, 2, ht_allow.ocns, ht_deny.ocns].flatten }
        let(:ht_allow) { build(:ht_item, rights: "pd") }
        let(:ht_deny) { build(:ht_item, rights: "ic") }
        before(:each) { load_test_data(ht_allow, ht_deny) }

        it "searches for each ocn" do
          # solr response has nothing in it;
          # should raise exception if we did some other query
          mock_solr_oclc_search(solr_response_for,
            filter: /oclc_search:\(#{ocns.join(" ")}\)/)

          data_source.dump_records(output)
        end

        it "counts input & matching ocns and saves them to a JSON file" do
          mock_solr_oclc_search(solr_response_for(ht_allow, ht_deny))
          data_source.dump_records(output)

          ocn_count_json = JSON.parse(File.read(ocn_count))
          expect(ocn_count_json["ocns_total"]).to eq(4)
          expect(ocn_count_json["ocns_matched"]).to eq(2)
        end
      end

      context "with one record with two ocns" do
        let(:ocns) { [1, 2] }
        before(:each) { File.write(ocn_file, ocns.join("\n")) }

        it "only writes each record once" do
          # create an htitem with two ocns
          ht_item = build(:ht_item, ocns: ocns)

          # query for only one of those OCNs at a time
          data_source = described_class.new(ocn_file: ocn_file, solr_query_size: 1)

          mock_solr_oclc_search(solr_response_for(ht_item), filter: /oclc_search:\(1\)/)
          mock_solr_oclc_search(solr_response_for(ht_item), filter: /oclc_search:\(2\)/)

          data_source.dump_records(output)
          expect(File.open(output).count).to eq(1)
        end
      end
    end
  end
end
