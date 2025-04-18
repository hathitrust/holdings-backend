require "services"
require "milemarker"
require "sidekiq/batch"
require "tmpdir"
require "sidekiq_jobs"
require "workflow_component"

module Workflows
  # Gets data (one record per line) from a data source, splits it into chunks,
  # then runs a job on each chunk (the "mapper"); when the mapping steps
  # complete, runs a callback (the "reducer") with the output
  # from the mapper.
  #
  # Jobs are run on files containing the given records_per_job lines (default 10,000)
  class MapReduce
    class Callback
      def on_success(_status, options)
        reducer = Object.const_get(options["component_class"])
        reducer_params = Jobs.symbolize(options["params"])
        reducer.new(**reducer_params).run

        # Don't delete intermediate files for now to aid in debugging.
        # In the future: consider removing by default, but disabling that if a debug flag is present.
        # FileUtils.remove_entry(options["working_directory"])
      end
    end

    def initialize(
      working_directory: default_working_directory,
      records_per_job: 10000,
      components: {},
      # for testing only; assumes running inline; runs the reduce step
      # immediately
      test_mode: false
    )
      if components.keys.to_set != COMPONENT_TYPES
        raise ArgumentError, "Components must be all of #{COMPONENT_TYPES}"
      end
      @components = components
      @records_per_job = records_per_job
      @inline = false
      @working_directory = working_directory
      @test_mode = test_mode

      yield self if block_given?
    end

    def run
      data_source.new.dump_records(allrecords)
      split_records
      queue_jobs
      inline_reduce if test_mode
    end

    private

    attr_reader :components, :records_per_job, :working_directory, :test_mode

    COMPONENT_TYPES = [:data_source, :mapper, :reducer].to_set

    COMPONENT_TYPES.each do |component|
      define_method(component) do
        components[component]
      end
    end

    def callback_params
      Jobs.prepare_params({
        component_class: reducer.component_class,
        params: reducer.params.merge(
          working_directory: working_directory
        )
      })
    end

    def batch
      Sidekiq::Batch.new.tap do |b|
        b.description = "map (#{mapper}) reduce (#{reducer}) workflow"
        b.on(:success, Callback, callback_params)
      end
    end

    def queue_jobs
      batch.jobs do
        Dir.glob("#{working_directory}/records_*.split").each do |chunk|
          Services.logger.info "Queueing chunk #{chunk} with #{mapper}"
          Jobs::Common.perform_async(mapper.component_class, mapper.params, chunk)
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
      system("split -d -a 5 --additional-suffix=.split -l #{records_per_job} #{allrecords} #{working_directory}/records_")
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
