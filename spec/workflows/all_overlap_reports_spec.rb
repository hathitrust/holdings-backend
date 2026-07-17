require "workflows/all_overlap_reports"

RSpec.describe Workflows::AllOverlapReports do

  # TODO test data source - should gather OCNs of holdings not matching items

  describe Workflows::AllOverlapReports::Analyzer do
    include_context "with tables for holdings"

    it "can generate all overlaps from a solr record" do
      Dir.mktmpdir do |tmpdir|
        # solr record (id 000000001) has one michigan-deposited mpm (mdp.39015066356547, enumchron v.1) with ocn 2779601
        h = build(:holding, ocn: 2779601, mono_multi_serial: 'mpm', enum_chron: 'v.1', local_id: 'test_local_id_upenn', organization: "upenn")
        # we get the enumchron from the ht item, not the holding
        h2 = build(:holding, ocn: 2779601, mono_multi_serial: 'mpm', enum_chron: 'vol.1', local_id: 'test_local_id_smu', organization: "smu", status: 'WD')
        load_test_data(h,h2)

        record_tmp = File.join(tmpdir,"record.ndj")
        FileUtils.copy(fixture("solr_catalog_record.ndj"),record_tmp)
        described_class.new(record_tmp).run

        # umich & upenn each have one mpm that two institutions hold
        outfile_lines = File.readlines(record_tmp + ".overlap.tsv")

        expect(outfile_lines.count).to eq(2)
        expect(outfile_lines).to include(['upenn','2779601','test_local_id_upenn','mpm','ic','deny','1','mdp.39015066356547','v.1'].join("\t") + "\n")
        expect(outfile_lines).to include(['smu','2779601','test_local_id_smu','mpm','ic','deny','1','mdp.39015066356547','v.1'].join("\t") + "\n")
      end
    end

    it "includes holdings matching the cluster but no items in it (mpm case)" do
      Dir.mktmpdir do |tmpdir|
        # solr record (id 000000001) has one michigan-deposited mpm (mdp.39015066356547, enumchron v.1) with ocn 2779601
        h = build(:holding, ocn: 2779601, mono_multi_serial: 'mpm', enum_chron: 'v.1', local_id: 'test_local_id_upenn_v1', organization: "upenn")
        # we get the enumchron from the ht item, not the holding
        h2 = build(:holding, ocn: 2779601, mono_multi_serial: 'mpm', enum_chron: 'v.2', local_id: 'test_local_id_upenn_v2', organization: "upenn")
        load_test_data(h,h2)

        record_tmp = File.join(tmpdir,"record.ndj")
        FileUtils.copy(fixture("solr_catalog_record.ndj"),record_tmp)
        described_class.new(record_tmp).run

        # upenn should have one match & one non-matching holding
        # note they need to have different local IDs for both to show up here
        outfile_lines = File.readlines(record_tmp + ".overlap.tsv")

        expect(outfile_lines.count).to eq(2)
        expect(outfile_lines).to include(['upenn','2779601','test_local_id_upenn_v1','mpm','ic','deny','1','mdp.39015066356547','v.1'].join("\t") + "\n")
        expect(outfile_lines).to include(['upenn','2779601','test_local_id_upenn_v2','mpm','','','','',''].join("\t") + "\n")
      end
    end

    it "does not include multiple identical records in the output" do
      Dir.mktmpdir do |tmpdir|
        h = build(:holding, ocn: 2779601, mono_multi_serial: 'mpm', enum_chron: 'v.1', local_id: 'test_local_id_upenn', organization: "upenn")
        h2 = build(:holding, ocn: 2779601, mono_multi_serial: 'mpm', enum_chron: 'v.1', local_id: 'test_local_id_upenn', organization: "upenn")

        load_test_data(h,h2)

        record_tmp = File.join(tmpdir,"record.ndj")
        FileUtils.copy(fixture("solr_catalog_record.ndj"),record_tmp)
        described_class.new(record_tmp).run

        # upenn should have one match & one non-matching holding
        # note they need to have different local IDs for both to show up here
        outfile_lines = File.readlines(record_tmp + ".overlap.tsv")

        expect(outfile_lines.count).to eq(1)
        expect(outfile_lines).to include(['upenn','2779601','test_local_id_upenn','mpm','ic','deny','1','mdp.39015066356547','v.1'].join("\t") + "\n")
      end
    end

    it "non-matching ocns" do
      Dir.mktmpdir do |tmpdir|
        h = build(:holding, ocn: 12345, mono_multi_serial: 'spm', local_id: 'test_local_id_upenn', organization: "upenn")
        h2 = build(:holding, ocn: 12345, mono_multi_serial: 'spm', local_id: 'test_local_id_umich', organization: "umich")

        load_test_data(h,h2)

        # TODO need to include as an OCN with no matching ht items here
        record_tmp = File.join(tmpdir,"unmatched.ndj")
        FileUtils.copy(fixture("unmatched_ocns.ndj"),record_tmp)
        described_class.new(record_tmp).run

        # upenn should have one match & one non-matching holding
        # note they need to have different local IDs for both to show up here
        outfile_lines = File.readlines(record_tmp + ".overlap.tsv")

        expect(outfile_lines.count).to eq(2)
        expect(outfile_lines).to include(['upenn','12345','test_local_id_upenn','spm','','','','',''].join("\t") + "\n")
        expect(outfile_lines).to include(['umich','12345','test_local_id_umich','spm','','','','',''].join("\t") + "\n")
      end

    end
  end
end
