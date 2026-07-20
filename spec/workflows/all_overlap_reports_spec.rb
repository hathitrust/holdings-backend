require "workflows/all_overlap_reports"

RSpec.describe Workflows::AllOverlapReports do
  include_context "with tables for holdings"

  describe Workflows::AllOverlapReports::DataSource do
    include_context "with mocked solr response"

    before(:each) do
      mock_solr_search_filtered(File.open(fixture("solr_response.json")), /deleted:false/)

      # TEMPORARY until we get this via mariadb client
      FileUtils.mkdir(Settings.overlap_reports_path) unless File.exist?(Settings.overlap_reports_path)
      File.open(File.join(Settings.overlap_reports_path, "distinct_holdings_ocn.sort"), "w") do |fh|
        # these two are not in solr response
        fh.puts("12345")
        fh.puts("34")
        # this is in solr_reponse so shouldn't be in the output
        fh.puts("75")
      end
    end

    it "generates records for holdings OCNs w/o records in HT" do
      # NOT loading from holdings for the time being
      # load_test_data(
      #   # these two are not in solr response
      #   build(:holding, ocn: 12345),
      #   build(:holding, ocn: 34),
      #   # this is in solr_reponse so shouldn't be in the output
      #   build(:holding, ocn: 75),
      # )

      Dir.mktmpdir do |tmpdir|
        output = File.join(tmpdir, "allrecords.ndj")
        described_class.new.dump_records(output)

        records = File.readlines(output).map { |l| JSON.parse(l) }
        itemless_records = records.select { |r| r["ht_json"] == "[]" }

        expect(itemless_records).to contain_exactly(
          {"format" => "Unknown", "oclc_search" => [12345], "ht_json" => "[]"},
          {"format" => "Unknown", "oclc_search" => [34], "ht_json" => "[]"}
        )
      end
    end
  end

  # TODO test data source - should gather OCNs of holdings not matching items

  describe Workflows::AllOverlapReports::Analyzer do
    it "can generate all overlaps from a solr record" do
      Dir.mktmpdir do |tmpdir|
        # solr record (id 000000001) has one michigan-deposited mpm (mdp.39015066356547, enumchron v.1) with ocn 2779601
        h = build(:holding, ocn: 2779601, mono_multi_serial: "mpm", enum_chron: "v.1", local_id: "test_local_id_upenn", organization: "upenn")
        # we get the enumchron from the ht item, not the holding
        h2 = build(:holding, ocn: 2779601, mono_multi_serial: "mpm", enum_chron: "vol.1", local_id: "test_local_id_smu", organization: "smu", status: "WD")
        load_test_data(h, h2)

        record_tmp = File.join(tmpdir, "record.ndj")
        FileUtils.copy(fixture("solr_catalog_record.ndj"), record_tmp)
        described_class.new(record_tmp).run

        # umich & upenn each have one mpm that two institutions hold
        outfile_lines = File.readlines(record_tmp + ".overlap.tsv")

        expect(outfile_lines.count).to eq(2)
        expect(outfile_lines).to include(["upenn", "2779601", "test_local_id_upenn", "mpm", "ic", "deny", "1", "mdp.39015066356547", "v.1"].join("\t") + "\n")
        expect(outfile_lines).to include(["smu", "2779601", "test_local_id_smu", "mpm", "ic", "deny", "1", "mdp.39015066356547", "v.1"].join("\t") + "\n")
      end
    end

    it "includes holdings matching the cluster but no items in it (mpm case)" do
      Dir.mktmpdir do |tmpdir|
        # solr record (id 000000001) has one michigan-deposited mpm (mdp.39015066356547, enumchron v.1) with ocn 2779601
        h = build(:holding, ocn: 2779601, mono_multi_serial: "mpm", enum_chron: "v.1", local_id: "test_local_id_upenn_v1", organization: "upenn")
        # we get the enumchron from the ht item, not the holding
        h2 = build(:holding, ocn: 2779601, mono_multi_serial: "mpm", enum_chron: "v.2", local_id: "test_local_id_upenn_v2", organization: "upenn")
        load_test_data(h, h2)

        record_tmp = File.join(tmpdir, "record.ndj")
        FileUtils.copy(fixture("solr_catalog_record.ndj"), record_tmp)
        described_class.new(record_tmp).run

        # upenn should have one match & one non-matching holding
        # note they need to have different local IDs for both to show up here
        outfile_lines = File.readlines(record_tmp + ".overlap.tsv")

        expect(outfile_lines.count).to eq(2)
        expect(outfile_lines).to include(["upenn", "2779601", "test_local_id_upenn_v1", "mpm", "ic", "deny", "1", "mdp.39015066356547", "v.1"].join("\t") + "\n")
        expect(outfile_lines).to include(["upenn", "2779601", "test_local_id_upenn_v2", "mpm", "", "", "", "", ""].join("\t") + "\n")
      end
    end

    it "does not include multiple identical records in the output" do
      Dir.mktmpdir do |tmpdir|
        h = build(:holding, ocn: 2779601, mono_multi_serial: "mpm", enum_chron: "v.1", local_id: "test_local_id_upenn", organization: "upenn")
        h2 = build(:holding, ocn: 2779601, mono_multi_serial: "mpm", enum_chron: "v.1", local_id: "test_local_id_upenn", organization: "upenn")

        load_test_data(h, h2)

        record_tmp = File.join(tmpdir, "record.ndj")
        FileUtils.copy(fixture("solr_catalog_record.ndj"), record_tmp)
        described_class.new(record_tmp).run

        # upenn should have one match & one non-matching holding
        # note they need to have different local IDs for both to show up here
        outfile_lines = File.readlines(record_tmp + ".overlap.tsv")

        expect(outfile_lines.count).to eq(1)
        expect(outfile_lines).to include(["upenn", "2779601", "test_local_id_upenn", "mpm", "ic", "deny", "1", "mdp.39015066356547", "v.1"].join("\t") + "\n")
      end
    end

    it "non-matching ocns" do
      Dir.mktmpdir do |tmpdir|
        h = build(:holding, ocn: 12345, mono_multi_serial: "spm", local_id: "test_local_id_upenn", organization: "upenn")
        h2 = build(:holding, ocn: 12345, mono_multi_serial: "spm", local_id: "test_local_id_umich", organization: "umich")

        load_test_data(h, h2)

        # TODO need to include as an OCN with no matching ht items here
        record_tmp = File.join(tmpdir, "unmatched.ndj")
        FileUtils.copy(fixture("unmatched_ocns.ndj"), record_tmp)
        described_class.new(record_tmp).run

        # upenn should have one match & one non-matching holding
        # note they need to have different local IDs for both to show up here
        outfile_lines = File.readlines(record_tmp + ".overlap.tsv")

        expect(outfile_lines.count).to eq(2)
        expect(outfile_lines).to include(["upenn", "12345", "test_local_id_upenn", "spm", "", "", "", "", ""].join("\t") + "\n")
        expect(outfile_lines).to include(["umich", "12345", "test_local_id_umich", "spm", "", "", "", "", ""].join("\t") + "\n")
      end
    end

    describe Workflows::AllOverlapReports::Writer do
      let(:orgs) { %w[umich smu upenn] }

      def open_gz_report(org)
        Zlib::GzipReader.open(Dir.glob("#{ENV["TEST_TMP"]}/overlap_reports/overlap_#{org}_*.gz").first)
      end

      before(:each) do
        FileUtils.copy(fixture("all_org_overlap_report_part.tsv"), File.join(ENV["TEST_TMP"], "records_00000.overlap.tsv"))
      end

      it "creates a gz for each represented org with the correct # of lines" do
        described_class.new(working_directory: ENV["TEST_TMP"]).run

        expect(open_gz_report("umich").readlines.count).to eq(2)
        expect(open_gz_report("smu").readlines.count).to eq(2)
        expect(open_gz_report("upenn").readlines.count).to eq(3)
      end

      it "removes the org from the line" do
        described_class.new(working_directory: ENV["TEST_TMP"]).run

        orgs.each do |org|
          # i.e. line starts with oclc number, not org
          expect(open_gz_report(org).readlines).to all match(/^(oclc|\d+)\t/)
        end
      end

      # local IDs should be included; the fixture includes the org name in the local id
      it "puts matching lines in the expected file" do
        described_class.new(working_directory: ENV["TEST_TMP"]).run

        orgs.each do |org|
          # local IDs contain the organization name
          expect(open_gz_report(org).readlines).to all match(/(local_id|#{org})/)
        end
      end
    end
  end
end
