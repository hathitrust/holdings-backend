# frozen_string_literal: true

require "scrub/chunker_error"
require "services"
require "securerandom"

module Scrub
  # Wrapper for shell split(1).
  # Take a glob of scrubbed files, sort, and then make
  # #{chunk_count} equal-sized (roughly) files from them.
  class Chunker
    attr_reader :glob, :chunks
    def initialize(glob: "/dev/null", chunk_count: 16, add_uuid: false)
      @glob = glob # to one or more files
      @chunks = [] # store paths to output files here
      @chunk_count = chunk_count
      @add_uuid = add_uuid
      @work_dir = Settings.scrub_chunk_work_dir
      if @work_dir.nil?
        raise Scrub::ChunkerError, "Settings.scrub_chunk_work_dir must be set, is nil"
      end
      @uuid = SecureRandom.uuid
      FileUtils.mkdir_p("#{@work_dir}/#{@uuid}")
    end

    def run
      # First we need to get all the data from @glob into one file.
      # `split --number=l/x` only works on files, not on STDIN.
      # TODO: we might want another dir for sort -T .
      tmp_file = "#{@work_dir}/#{@uuid}/tmp_sorted.txt"
      add_uuid_call = @add_uuid ? "| bundle exec ruby bin/add_uuid.rb" : "" 
      sort_call = "egrep -vh '^OCN' #{@glob} | " \
                  "sort -s -n -k1,1 -T ./ " \
                  "#{add_uuid_call} " \
                  "> #{tmp_file}"
      puts sort_call
      sort_exit_code = system sort_call

      unless sort_exit_code
        raise Scrub::ChunkerError, "Sort call failed?"
      end

      # Now we can split input lines into roughly-equal sized output files.
      split_call = "split -d --number=l/#{@chunk_count} " \
                   "#{tmp_file} '#{@work_dir}/#{@uuid}/split_'"
      puts split_call
      split_exit_code = system split_call

      unless split_exit_code
        raise ChunkerError, "Split call failed?"
      end

      # Rename and tell ruby about the resulting files.
      @chunks = Dir.new("#{@work_dir}/#{@uuid}")
        .select { |fn| fn =~ /^split_\d+$/ }
        .sort
        .map { |fn| rename("#{@work_dir}/#{@uuid}/#{fn}") }

      # Tmp file serves no further purpose
      FileUtils.rm(tmp_file)
    end

    # Just adds file ext.
    def rename(fn)
      FileUtils.mv(fn, "#{fn}.tsv")
      # Return new name
      "#{fn}.tsv"
    end

    # These can start taking up a lot of space and are ~worthless once loaded.
    def cleanup!
      puts "rm -rf #{@work_dir}/#{@uuid}"
      FileUtils.rm_rf("#{@work_dir}/#{@uuid}")
    end
  end
end
