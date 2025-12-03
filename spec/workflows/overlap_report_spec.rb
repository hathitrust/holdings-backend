require "workflows/map_reduce"
require "workflows/overlap_report"

RSpec.describe Workflows::OverlapReport do
  def open_gz_report(org)
    Zlib::GzipReader.open(Dir.glob("#{ENV["TEST_TMP"]}/overlap_reports/overlap_#{org}_*.gz").first)
  end

  describe Workflows::OverlapReport::Writer do
    def writer_for_org(org)
      described_class.new(organization: org, working_directory: ENV["TEST_TMP"])
    end

    describe "#initialize" do
      it "makes directories if they don't exist" do
        expect(File).not_to exist(Settings.overlap_reports_path)
        expect(File).not_to exist(Settings.local_report_path)

        writer = writer_for_org("umich")
        writer.run

        expect(File).to exist(Settings.overlap_reports_path)
        expect(File).to exist(Settings.local_report_path)
      end
    end

    it "puts the gzipped report to the persistent storage path" do
      writer = writer_for_org("umich")
      writer.run

      persistent_file = File.join(Settings.overlap_reports_path,
        writer.report_filename)
      expect(File).to exist(persistent_file)
    end

    it "copies the gzipped report to the remote path" do
      writer = writer_for_org("umich")
      writer.run

      File.join(Settings.overlap_reports_remote_path,
        writer.report_filename)
      writer_for_org("umich").run

      remote_file = File.join(Settings.overlap_reports_remote_path,
        "umich-hathitrust-member-data", "analysis",
        writer.report_filename)
      expect(File).to exist(remote_file)
    end

    it "writes a gzip file with the organization and date" do
      writer = writer_for_org("smu")
      writer.run

      path = File.join(ENV["TEST_TMP"], "overlap_reports", "overlap_smu_#{Date.today}.tsv.gz")
      expect(File).to exist(path)
    end

    it "gives a 'nonus' filename for non-us orgs" do
      writer = writer_for_org("uct")
      writer.run

      path = File.join(ENV["TEST_TMP"], "overlap_reports", "overlap_uct_#{Date.today}_nonus.tsv.gz")
      expect(File).to exist(path)
    end

    it "has a header" do
      writer = writer_for_org("smu")
      writer.run

      expect(open_gz_report("smu").to_a).to eq([writer.header + "\n"])
    end
  end

  describe "integration test with Workflow::MapReduce" do
    include_context "with tables for holdings"
    include_context "with mocked solr response"

    def workflow_component(component, org)
      WorkflowComponent.new(
        Object.const_get("Workflows::OverlapReport::#{component}"),
        {organization: org}
      )
    end

    def workflow_for_org(org,
      data_source: workflow_component("DataSource", org),
      mapper: workflow_component("Analyzer", org),
      reducer: workflow_component("Writer", org))
      components = {
        data_source: data_source,
        mapper: mapper,
        reducer: reducer
      }
      Workflows::MapReduce.new(test_mode: true, components: components)
    end

    context "with two holdings and htitems" do
      let(:h) { build(:holding, ocn: 1, organization: "umich") }
      let(:h2) { build(:holding, ocn: 2, organization: "ualberta") }
      let(:ht) { build(:ht_item, ocns: [h.ocn], access: "deny") }
      let(:ht2) { build(:ht_item, ocns: [h.ocn], access: "allow", rights: "pd") }

      before(:each) do
        load_test_data(h, h2, ht, ht2)
        mock_solr_oclc_search(solr_response_for(ht, ht2))
      end

      it "has a line for each ht_item in the holding organization rpt, plus a header line" do
        workflow_for_org(h.organization).run
        lines = open_gz_report(h.organization).to_a
        expect(lines.size).to eq(3)
      end

      it "has 8 columns in the report" do
        workflow_for_org(h.organization).run
        lines = open_gz_report(h.organization).to_a.map { |x| x.split("\t") }
        expect(lines.map(&:size)).to all(be == 8)
      end

      it "has 1 line with empty rights/access for holdings on clusters without HTItems" do
        workflow_for_org(h2.organization).run
        lines = open_gz_report(h2.organization).to_a
        expect(lines.size).to eq(2)
        rec = lines.last.split("\t")
        expect(rec[3]).to eq("")
        expect(rec[7]).to eq("\n")
      end

      it "has records for holdings that don't match HTItems" do
        # should include the ualberta holding even though it doesn't match any ht items
        workflow_for_org("ualberta").run
        recs = open_gz_report("ualberta").to_a
        expected_rec = ["2", h2.local_id, h2.mono_multi_serial,
          "", "", "", "", ""].join("\t") + "\n"
        expect(recs).to include(expected_rec)
      end
    end

    context "with two holdings with the same local id but different enumchron" do
      let(:h1) { build(:holding, mono_multi_serial: "mpm", enum_chron: "V.1") }
      let(:h2) do
        build(:holding, mono_multi_serial: "mpm", ocn: h1.ocn,
          organization: h1.organization, local_id: h1.local_id, enum_chron: "V.2")
      end
      let(:workflow) { workflow_for_org(h1.organization) }

      before(:each) do
        load_test_data(h1, h2)
      end

      it "writes only 1 no-match record" do
        mock_solr_oclc_search(solr_response_for)
        workflow.run
        expect(open_gz_report(h1.organization).count)
          .to eq(2)
      end

      it "writes only 1 match record" do
        ht = build(:ht_item, ocns: [h1.ocn], bib_fmt: "SE", enum_chron: "V.3")
        load_test_data(ht)
        mock_solr_oclc_search(solr_response_for(ht))
        workflow.run
        recs = open_gz_report(h1.organization).to_a
        expect(recs.count).to eq(2)
        expect(recs.last.chomp).to eq([h1.ocn, h1.local_id, h1.mono_multi_serial, ht.rights,
          ht.access, ht.ht_bib_key, ht.item_id,
          ht.enum_chron].join("\t"))
      end

      it "writes only the 1 record that matches" do
        ht = build(:ht_item, ocns: [h1.ocn], bib_fmt: "BK", enum_chron: "V.2")
        load_test_data(ht)
        mock_solr_oclc_search(solr_response_for(ht))
        workflow.run
        recs = open_gz_report(h1.organization).to_a
        expect(recs.count).to eq(2)
        expect(recs.last.chomp).to eq([h1.ocn, h1.local_id, h1.mono_multi_serial, ht.rights,
          ht.access, ht.ht_bib_key, ht.item_id,
          ht.enum_chron].join("\t"))
      end
    end
  end
end
