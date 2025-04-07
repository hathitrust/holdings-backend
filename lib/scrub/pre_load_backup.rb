require "json"

# Use this class in the following context:
# You want to load a new monographs file from Test U.
# First you want to make sure that the already loaded records are backed up,
# and then deleted.
#
# Scrub::PreLoadBackup.new(...).run will write the backup file and mark
# the existing matching records for deletion.
# Scrub::PreLoadBackup.new(...).delete_marked! will delete matching marked records.
#
# Invoke via phctl:
# $ bash phctl.sh backup holdings --organization umich --mono_multi_serial spm
# $ bash phctl.sh backup holdings --organization umich --mono_multi_serial spm mpm ser

module Scrub
  class PreLoadBackup
    attr_reader :organization, :mono_multi_serial

    def initialize(organization:, mono_multi_serial:)
      @organization = organization
      @mono_multi_serial = mono_multi_serial
      validate
    end

    def write_backup_file
      # Note that this writes an empty file if there are no matching records.
      File.open(backup_path, "w") do |backup_file|
        records.order(:uuid).paged_each do |record|
          backup_file.puts record.to_json
        end
      end
    end

    def mark_for_deletion
      records.update(delete_flag: 1)
    end

    def delete_marked!
      records.where(delete_flag: 1).delete
    end

    def backup_path
      File.join(Settings.backup_dir, file_name)
    end

    def match_count
      records.count
    end

    def marked_count
      records.where(delete_flag: 1).count
    end

    private

    def records
      Services.holdings_db[:holdings].where(query)
    end

    def query
      {
        organization: organization,
        mono_multi_serial: mono_multi_serial
      }
    end

    def file_name
      date = Time.new.strftime("%Y%m%d")
      "#{organization}_#{mono_multi_serial}_full_#{date}_backup.ndj"
    end

    def validate
      if Settings.backup_dir.nil?
        raise "Need Settings.backup_dir to be set"
      end
      if !File.exist? Settings.backup_dir
        Services.logger.info "creating backup directory #{Settings.backup_dir}"
        FileUtils.mkdir_p Settings.backup_dir
      end
    end
  end
end
