require "workflows/all_overlap_reports"

RSpec.describe Workflows::AllOverlapReports do

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

    it "deposited but not held items"
    it "holdings matching the cluster but no items in it (mpm case)"
    it "multiple identical report records (exploded ocns?)" 
    it "non-matching ocns"
  end
end
