require "services"
require "settings"
require "utils/slack_notifier"

module Workflows
  class OverlapWriter
    def initialize(working_directory:, report_record_class:)
      @working_directory = working_directory
      @local_report_path = Settings.local_report_path || "local_reports"
      @report_record_class = MapReduce.to_class(report_record_class)
      Dir.mkdir(@local_report_path) unless File.exist?(@local_report_path)
      @persistent_report_path = Settings.overlap_reports_path
      Dir.mkdir(@persistent_report_path) unless File.exist?(@persistent_report_path)
      @remote_report_path = Settings.overlap_reports_remote_path
    end

    def run
      if Dir.glob(File.join(working_directory, "*.overlap.tsv")).empty?
        raise "No overlap report files found in #{working_directory}"
      end

      collate_report
      finalize_report
    end

    def notify
      Utils::SlackNotifier.post(notification_message)
    end

    def header
      report_record_class.header
    end

    def report_filename(organization)
      nonus = (Services.ht_organizations[organization]&.country_code == "us") ? "" : "_nonus"
      "overlap_#{organization}_#{Date.today}#{nonus}.tsv.gz"
    end

    protected

    attr_reader :local_report_path, :persistent_report_path, :remote_report_path, :organization, :working_directory, :report_record_class

    def report_gz_path(organization)
      File.join(local_report_path, report_filename(organization))
    end

    def dropbox_url(organization)
      "#{Settings.overlap_reports_remote_path_url}/#{organization}-hathitrust-member-data/analysis/#{report_filename(organization)}"
    end

    def rclone_move(file, org)
      remote_path = "#{@remote_report_path}/#{org}-hathitrust-member-data/analysis"
      Services.logger.info("Uploading #{file} to #{remote_path}")
      system("rclone",
        "--config", Settings.rclone_config_path,
        "move", File.path(file), remote_path,
        exception: true)
    end

    def collate_report
      raise "unimplemented"
    end

    def finalize_report
      raise "unimplemented"
    end

    def notification_message
      raise "unimplemented"
    end
  end
end
