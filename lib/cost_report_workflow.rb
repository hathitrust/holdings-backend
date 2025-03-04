require "faraday"
require "json"
require "milemarker"
require "reports/cost_report"
require "sidekiq/batch"
require "sidekiq_jobs"
require "solr/cursorstream"

class CostReportWorkflow
  class CostReportWorkflow::Callback
    def on_success(_status, options)
      Reports::CostReport.new(precomputed_frequency_table_dir: options["frequency_table_dir"]).run
      # Don't delete intermediate files for now to aid in debugging.
      # In the future: consider removing by default, but disabling that if a debug flag is present.
      # FileUtils.remove_entry(options["frequency_table_dir"])
    end
  end

  def initialize(working_directory: default_working_directory,
    chunk_size: 10000,
    inline_callback_test: false)
    @working_directory = working_directory
    @chunk_size = chunk_size
    @inline_callback_test = inline_callback_test
  end

  def run
    dump_solr_records
    split_solr_records
    queue_frequency_table_jobs
  end

  private

  attr_reader :working_directory, :chunk_size, :inline_callback_test

  def default_working_directory
    work_base = File.join(Settings.cost_report_path, "work")
    FileUtils.mkdir_p(work_base)
    Dir.mktmpdir("costreport_", work_base)
  end

  def allrecords_ndj
    File.join(working_directory, "allrecords.ndj")
  end

  def dump_solr_records
    core_url = ENV["SOLR_URL"]
    milemarker = Milemarker.new(batch_size: 50000, name: "get solr records")
    milemarker.logger = Services.logger

    File.open(allrecords_ndj, "w") do |out|
      Solr::CursorStream.new(url: core_url) do |s|
        s.fields = %w[ht_json id oclc oclc_search title format]
        ic_rights = Clusterable::HtItem::IC_RIGHTS_CODES.join(" ")
        s.filters = ["ht_rightscode:(#{ic_rights})"]
        s.batch_size = 5000
      end.each do |record|
        out.puts record.to_json
        milemarker.increment_and_log_batch_line
      end
    end

    milemarker.log_final_line
  end

  def split_solr_records
    system("split -d -a 5 --additional-suffix=.ndj -l #{chunk_size} #{allrecords_ndj} #{working_directory}/records_")
  end

  def queue_frequency_table_jobs
    batch = Sidekiq::Batch.new
    callback_params = {"frequency_table_dir" => working_directory}
    batch.description = "Generate frequency tables for cost report"
    batch.on(:success, CostReportWorkflow::Callback, callback_params)
    batch.jobs do
      Dir.glob("#{working_directory}/records_*.ndj").each do |chunk|
        outfile = File.join(working_directory, File.basename(chunk, ".ndj")) + ".freqtable.json"
        Services.logger.info "Queueing chunk #{chunk}"
        Jobs::Common.perform_async("Reports::FrequencyTableFromSolr", {},
          chunk, outfile)
      end
    end
    # In test, where sidekiq is not running, we do this
    # instead of relying on the on_success-hook.
    if @inline_callback_test
      Services.logger.info("Running cost report inline -- TEST ONLY")
      CostReportWorkflow::Callback.new.on_success(:success, callback_params)
    end
  end
end
