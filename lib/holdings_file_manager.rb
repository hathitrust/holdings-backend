# frozen_string_literal: true

require "services"
require "date"
require "holdings_file"
require "loaded_file"

# Usage:
#
# HoldingsFileManager.new.try_scrub
#
# Attempts to scrub all files in #{Settings.holdings_path}/new.
#
# HoldingsFileManager.new.try_load
#
# Attempts to load all holdings files in DIRECTORY. Successfully loaded files
# will be placed in OUTPUT_pathECTORY; failures will be reported to CHANNEL.
# Will not load files if the loading flag is set.
#
class HoldingsFileManager

  def initialize(holdings_file_factory: ->(path) { HoldingsFile.new(path) },
                 loading_flag: Services.loading_flag,
                 scrub_path: holdings_path("new"),
                 member_data_path: holdings_path("member_data"))
    @holdings_file_factory = holdings_file_factory
    @loading_flag = loading_flag
    @scrub_path = scrub_path
    @member_data_path = member_data_path
  end

  def try_scrub
    # TODO: use Autoscrub directly here?
    # TODO: record member & date of submission?
    Dir.glob(scrub_path / "*.tsv") do |scrub_file|
      holdings_file_factory.call(scrub_file).scrub
    end
  end

  def try_load
    require 'pry'
    binding.pry

    return unless files_to_load.any?

    # TODO: decide what we want the locking semantics to be -- are multiple
    # loading processes OK? Is running certain kinds of reports (i.e.
    # estimates) OK during loading? For some reports (e.g. member fees) we want
    # to be able to say that they're based on the full set of data submitted as
    # of a particular date.
    #
    # TODO: HoldingsFile -> ScrubbedHoldingsFile?
    # TODO: extract member & date of submission?


    loading_flag.with_lock do
      files_to_load.each { |f| holdings_file_factory.call(f).load }
    end
  end

  private

  attr_reader :holdings_file_factory, :loading_flag, :scrub_path, :member_data_path

  def files_to_load
    @files_to_load ||= Dir.glob(member_data_path / "*" / "ready_to_load" / "*.ndj")
  end

  def holdings_path(subdir = "")
    Pathname.new(Settings.holdings_path) / subdir
  end

end
