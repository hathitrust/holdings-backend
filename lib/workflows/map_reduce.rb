require "services"
require "milemarker"
require "sidekiq/batch"
require "tmpdir"
require "sidekiq_jobs"

module Workflows
  class Callback
    def on_success(_status, options)
      reducer = Object.const_get(options["reducer"])
      reducer_params = options["reducer_params"]
        .transform_keys(&:to_sym)

      reducer.new(**reducer_params).run

      # Don't delete intermediate files for now to aid in debugging.
      # In the future: consider removing by default, but disabling that if a debug flag is present.
      # FileUtils.remove_entry(options["working_directory"])
    end
  end

  # Gets data (one record per line) from a data source, splits it into chunks,
  # then runs a job on each chunk (the "mapper"); when the mapping steps
  # complete, runs a callback (the "reducer") with the output
  # from the mapper.
  #
  # Jobs are run in chunks of the given chunk_size lines (default 10,000)
  class MapReduce
    def initialize(
      data_source:,
      mapper:, reducer:, data_source_params: {},
      mapper_params: {},
      reducer_params: {},
      working_directory: default_working_directory,
      chunk_size: 10000,
      # for testing only; assumes running inline; runs the reduce step
      # immediately
      test_mode: false
    )
      @reducer_params = reducer_params
      @chunk_size = chunk_size
      @data_source = Object.const_get(data_source)
      @data_source_params = data_source_params
      @inline = false

      @mapper = mapper
      @mapper_params = mapper_params
      @reducer = reducer
      @reducer_params = reducer_params
      @working_directory = working_directory
      @test_mode = test_mode
    end

    def run
      data_source.new(**data_source_params.transform_keys { |k| k.to_sym }).dump_records(allrecords)
      split_records
      queue_jobs
      inline_reduce if test_mode
    end

    private

    attr_reader :chunk_size, :mapper, :mapper_params, :reducer, :reducer_params, :data_source, :data_source_params, :working_directory, :test_mode

    def callback_params
      {
        "reducer" => reducer,
        "reducer_params" => reducer_params.merge(
          "working_directory" => working_directory
        )
      }
    end

    def batch
      Sidekiq::Batch.new.tap do |b|
        b.description = "map (#{@mapper}) reduce (#{@reducer}) workflow"
        b.on(:success, Callback, callback_params)
      end
    end

    def queue_jobs
      batch.jobs do
        Dir.glob("#{working_directory}/records_*.split").each do |chunk|
          Services.logger.info "Queueing chunk #{chunk} with #{mapper}"
          Jobs::Common.perform_async(mapper, mapper_params, chunk)
        end
      end
    end

    def default_working_directory
      work_base = File.join(Settings.cost_report_path, "work")
      FileUtils.mkdir_p(work_base)
      Dir.mktmpdir("mapreduce_", work_base)
    end

    def allrecords
      File.join(working_directory, "allrecords")
    end

    def split_records
      system("split -d -a 5 --additional-suffix=.split -l #{chunk_size} #{allrecords} #{working_directory}/records_")
    end

    def inline_reduce
      # In test, where sidekiq is not running, we do this
      # instead of relying on the on_success-hook.
      if ENV["DATABASE_ENV"] == "test"
        Services.logger.info("Running reduce step inline -- TEST ONLY")
        Callback.new.on_success(:success, callback_params)
      end
    end
  end
end
