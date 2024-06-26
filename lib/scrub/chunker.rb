# frozen_string_literal: true

require "scrub/chunker_error"
require "services"
require "securerandom"

module Scrub
  # Wrapper for shell split(1).
  # Take a glob of scrubbed files, sort, and then make
  # #{chunk_count} equal-sized (roughly) files from them.
  class Chunker
    attr_reader :glob, :chunks, :tmp_chunk_dir
    def initialize(glob, chunk_count: 16, add_uuid: false, out_ext: nil)
      @glob = glob # to one or more files
      @chunks = [] # store paths to output files here
      @chunk_count = chunk_count
      @add_uuid = add_uuid
      @work_dir = Settings.scrub_chunk_work_dir

      if @work_dir.nil?
        raise ArgumentError, "Missing Settings.scrub_chunk_work_dir"
      end

      @uuid = SecureRandom.uuid
      @out_ext = out_ext # Apply this extension to the resulting file(s).
      @tmp_chunk_dir = File.join(@work_dir, @uuid)
      FileUtils.mkdir_p(@tmp_chunk_dir)
    end

    def validate
      if @work_dir.nil?
        raise Scrub::ChunkerError, "Settings.scrub_chunk_work_dir must be set, is nil"
      end
      if @out_ext.nil?
        raise Scrub::ChunkerError, "No output extension specified (@out_ext)"
      end
    end

    def run
      # First we need to get all the data from @glob into one file.
      # `split --number=l/x` only works on files, not on STDIN.
      tmp_file = File.join(@tmp_chunk_dir, "tmp_sorted.txt")
      add_uuid_call = @add_uuid ? "| bundle exec ruby bin/add_uuid.rb" : ""
      # Sort call explained:
      # input lines look like {"ocn":7804,"local_id":"991000029949706390", ... }
      # -t:   = split lines into fields on :
      # -k2,2 = only sort based on the 2nd field (7804,"local_id")
      # -s    = stable sort, which should make it faster?
      # -n    = numeric sort so [1, 3, 20] instead of [1, 20, 3]
      # -T ./ = put temporary files in the current directory
      sort_call = "egrep -vh '^OCN' #{@glob} | " \
                  "sort -t: -k2,2 -s -n" \
                  "#{add_uuid_call} " \
                  "> #{tmp_file}"
      Services.logger.info sort_call
      sort_exit_code = system sort_call

      unless sort_exit_code
        raise Scrub::ChunkerError, "Sort call failed?"
      end

      # Now we can split input lines into roughly-equal sized output files.
      split_call = "split -d --number=l/#{@chunk_count} " \
                   "#{tmp_file} '#{@work_dir}/#{@uuid}/split_'"
      Services.logger.info split_call
      split_exit_code = system split_call

      unless split_exit_code
        raise ChunkerError, "Split call failed?"
      end

      # Rename and tell ruby about the resulting files.
      @chunks = Dir.new(@tmp_chunk_dir)
        .select { |fn| fn =~ /^split_\d+$/ }
        .sort
        .map { |fn| rename(File.join(@tmp_chunk_dir, fn)) }

      # Tmp file serves no further purpose
      FileUtils.rm(tmp_file)
    end

    # Just adds file ext.
    def rename(fn)
      FileUtils.mv(fn, "#{fn}.#{@out_ext}")
      # Return new name
      "#{fn}.#{@out_ext}"
    end

    # These can start taking up a lot of space and are ~worthless once loaded.
    def cleanup!
      Services.logger.info "rm -rf #{@tmp_chunk_dir}"
      FileUtils.rm_rf(@tmp_chunk_dir)
    end
  end
end
