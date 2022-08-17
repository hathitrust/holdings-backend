require "services"
require "utils/file_transfer_error"

module Utils
  # Use rclone system calls to transfer files between
  # local and remote storage (and vice versa).
  class FileTransfer
    def initialize
      # Check that config is set...
      if Settings.rclone_config_path.nil?
        raise "Settings.rclone_config_path missing from Settings"
      end
      # ... and points to an actual file.
      unless File.exist?(Settings.rclone_config_path)
        raise "Settings.rclone_config_path points to " \
              "#{Settings.rclone_config_path}, which does not exist"
      end
    end

    # Really just an alias for transfer
    def upload(local_file, remote_dir)
      transfer(local_file, remote_dir)
    end

    # Really just an alias for transfer
    def download(remote_file, local_dir)
      transfer(remote_file, local_dir)
    end

    def exists?(dir)
      make_call("#{call_prefix} ls \"#{dir}\"")
    end

    def mkdir_p(dir)
      make_call("#{call_prefix} mkdir \"#{dir}\"")
    end

    # Return parsed JSON ls output
    def lsjson(remote_dir)
      # Never parse ls output, let rclone do it for us.
      call = "#{call_prefix} lsjson \"#{remote_dir}\""
      puts "call #{call}"
      response = `#{call}`
      puts "response #{response}"
      JSON.parse(response)
    rescue JSON::ParserError => err
      raise Utils::FileTransferError, "Could not ls #{remote_dir}... #{err}"
    end

    private

    def make_call(sys_call)
      puts sys_call
      # returns true/false based on exit code of the executed system call
      system sys_call
    end

    # Any call will start with:
    def call_prefix
      "rclone --config #{Settings.rclone_config_path}"
    end

    def transfer(file, dir)
      unless exists?(file)
        raise Utils::FileTransferError, "file #{file} does not exist"
      end

      unless exists?(dir)
        raise Utils::FileTransferError, "dir #{dir} does not exist"
      end

      puts "transfer #{file} to #{dir}"
      make_call("#{call_prefix} copy #{file} #{dir}")
    end
  end
end
