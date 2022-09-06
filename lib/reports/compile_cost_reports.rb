#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "utils/ppnum"
require "reports/cost_report"

class CompileCostReport
  def to_tsv(report)
    tsv = []
    tsv << ["member_id", "spm", "mpm", "ser", "pd", "weight", "extra", "total"].join("\t")
    Services.ht_organizations.members.keys.sort.each do |member|
      next unless report.organization.nil? || (member == report.organization.to_s)
      tsv << [
        member,
        report.spm_costs(member),
        report.mpm_costs(member),
        report.ser_costs(member),
        report.pd_cost_for_member(member),
        Services.ht_organizations[member].weight,
        report.extra_per_member,
        report.total_cost_for_member(member)
      ].join("\t")
    end
    tsv.join("\n")
  end

  def run(org, cost = nil, output_filename = report_file)
    batch_size = 50_000
    marker = Services.progress_tracker.new(batch_size)
    logger = Services.logger
    logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum batch_size}"
    cost_report = Reports::CostReport.new(org, cost: cost, lines: batch_size, logger: logger)

    File.open(output_filename, "w") do |fh|
      fh.puts "Target cost: #{cost_report.target_cost}"
      fh.puts "Num volumes: #{cost_report.num_volumes}"
      fh.puts "Num pd volumes: #{cost_report.num_pd_volumes}"
      fh.puts "Cost per volume: #{cost_report.cost_per_volume}"
      fh.puts "Total weight: #{cost_report.total_weight}"
      fh.puts "PD Cost: #{cost_report.pd_cost}"
      fh.puts "Num members: #{Services.ht_organizations.members.count}"

      fh.puts to_tsv(cost_report)
    end

    # Dump freq table to file
    ymd = Time.new.strftime("%F")
    cost_report.dump_freq_table("freq_#{ymd}.txt")
    logger.info marker.final_line
  end

  private

  def report_file
    FileUtils.mkdir_p(Settings.cost_report_path)
    iso_stamp = Time.now.strftime("%Y%m%d-%H%M%S")
    File.join(Settings.cost_report_path, "cost_report_#{iso_stamp}.txt")
  end
end
