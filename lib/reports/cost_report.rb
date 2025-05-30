# frozen_string_literal: true

require "overlap/ht_item_overlap"
require "frequency_table"
require "services"

# In Aug 2023 we decided that items with rights:icus should behave as if
# they were access:allow (PD, everybody pay), instead of the traditional
# access:deny (IC, holders pay).

module Reports
  # Generates reports based on h_share
  class CostReport
    attr_reader :organization, :logger, :maxlines, :target_cost, :batch_size, :marker, :frequency_table

    def to_tsv tsv = []
      raise "no frequency table provided" unless @frequency_table
      tsv << ["member_id", "spm", "mpm", "ser", "pd", "weight", "extra", "total"].join("\t")
      Services.ht_organizations.members.keys.sort.each do |member|
        next unless organization.nil? || (member == organization)
        tsv << [
          member,
          spm_costs(member),
          mpm_costs(member),
          ser_costs(member),
          pd_cost_for_member(member),
          Services.ht_organizations[member].weight,
          extra_per_member,
          total_cost_for_member(member)
        ].join("\t")
      end
      tsv.join("\n")
    end

    def run(output_filename = report_file)
      logger.info "Starting #{Pathname.new(__FILE__).basename}."
      logger.info "Writing report to #{output_filename}"

      File.open(output_filename, "w") do |fh|
        fh.puts "Target cost: #{target_cost}"
        fh.puts "Num volumes: #{ht_item_count}"
        fh.puts "Num pd volumes: #{ht_item_pd_count}"
        fh.puts "Cost per volume: #{cost_per_volume}"
        fh.puts "Total weight: #{total_weight}"
        fh.puts "PD Cost: #{pd_cost}"
        fh.puts "Num members: #{Services.ht_organizations.members.count}"

        fh.puts to_tsv
      end

      # Dump freq table to file
      ymd = Time.new.strftime("%F")
      dump_frequency_table("frequency_#{ymd}.json")
      logger.info "Done"
    end

    def initialize(organization: nil,
      target_cost: Settings.target_cost,
      lines: 5000,
      logger: Services.logger,
      ht_item_pd_count: nil,
      ht_item_count: nil,
      frequency_table: nil,
      working_directory: nil,
      precomputed_frequency_table: read_freq_tables(working_directory, frequency_table))
      target_cost ||= Settings.target_cost

      raise "Target cost not set" if target_cost.nil?

      @organization = organization
      @target_cost = target_cost.to_f
      @maxlines = lines
      @logger = logger
      @ht_item_pd_count ||= ht_item_pd_count
      @ht_item_count ||= ht_item_count

      # If you pass a precomputed frequency table, do not modify it after passing it in.
      # This warning is in the place of actually implementing proper cloning.
      @frequency_table = precomputed_frequency_table
    end

    def ht_item_pd_count
      @ht_item_pd_count ||= Clusterable::HtItem.pd_count
    end

    def ht_item_count
      @ht_item_count ||= Clusterable::HtItem.count
    end

    def active_members
      @active_members ||=
        Services.ht_organizations.organizations.select { |_id, member| member.status }
    end

    def cost_per_volume
      @cost_per_volume ||= target_cost / ht_item_count.to_f
    end

    def total_weight
      @total_weight ||= active_members.map { |_id, member| member.weight }.sum
    end

    def pd_cost
      @pd_cost ||= cost_per_volume * ht_item_pd_count
    end

    def pd_cost_for_member(member)
      (pd_cost / total_weight) * active_members[member.to_s].weight
    end

    # Dump freq table so these computes can be re-used in member_counts_report.
    def dump_frequency_table(dump_fn = "freq.json")
      logger.info "Writing frequency table to #{dump_fn}"
      FileUtils.mkdir_p(Settings.cost_report_freq_path)
      File.open(File.join(Settings.cost_report_freq_path, dump_fn), "w") do |dump_file|
        dump_file.puts(frequency_table.to_json)
      end
    end

    def total_hscore(member)
      spm_total(member) + mpm_total(member) + ser_total(member)
    end

    [:spm, :ser, :mpm].each do |format|
      # HScore for a particular format
      define_method :"#{format}_total" do |member|
        total = 0.0
        frequency_table.frequencies(organization: member, format: format).each do |freq|
          total += freq.frequency.to_f / freq.member_count
        end
        total
      end

      # Costs for a particular format
      define_method :"#{format}_costs" do |member|
        public_send(:"#{format}_total", member) * cost_per_volume
      end
    end

    def total_ic_costs(member)
      total_hscore(member) * cost_per_volume
    end

    def extra_per_member
      total_ic_costs(:hathitrust) / (active_members.keys - ["hathitrust"]).count
    end

    def total_cost_for_member(member)
      total_ic_costs(member) + pd_cost_for_member(member) + extra_per_member
    end

    private

    # Reads either a set of frequency tables from a given directory containing
    # json files, or a single one from a file.
    #
    # If neither are given, read nothing, and compute the frequency table on
    # the fly.
    def read_freq_tables(dir, file)
      if dir && file
        raise ArgumentError "Must provide at most one of a directory or a file for precomputed frequency tables for cost report"
      end

      if dir
        # read all .json files in the given directory as frequency tables and
        # sum them together
        Dir.glob("#{dir}/*.json")
          .map { |file| FrequencyTable.new(data: File.read(file)) }
          .reduce(:+)
      elsif file
        FrequencyTable.new(data: File.read(file))
      end
    end

    def report_file
      year = Time.now.year.to_s
      FileUtils.mkdir_p(File.join(Settings.cost_report_path, year))
      iso_stamp = Time.now.strftime("%Y%m%d")

      File.join(
        Settings.cost_report_path,
        year,
        "costreport_#{iso_stamp}.tsv"
      )
    end
  end
end
