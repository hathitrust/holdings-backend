require "services"

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

    def upload(local_file, remote_dir)
      # check that local file and remote dir exist
      unless File.exist?(local_file)
        raise "local file #{local_file} does not exist"
      end
      transfer(File.path(local_file), remote_dir)
    end

    def download(remote_file, local_dir)
      transfer(remote_file, local_dir)
    end

    # Return parsed JSON ls output
    def ls_remote_dir(remote_dir)
      # Never parse ls output, let rclone do it for us.
      call = "#{call_prefix} lsjson #{remote_dir}"
      puts "call #{call}"
      response = `#{call}`
      puts "response #{response}"
      JSON.parse(response)
    end

    private

    # Any call will start with:
    def call_prefix
      "rclone --config #{Settings.rclone_config_path}"
    end

    def transfer(file, dir)
      puts "transfer #{file} to #{dir}"
      call = "#{call_prefix} copy #{file} #{dir}"
      puts call
      system(call)
    end
  end
end
