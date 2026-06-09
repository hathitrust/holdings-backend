# frozen_string_literal: true

require "open3"

require "data_sources/directory_locator"
require "ex_libris_holdings_xml_parser"
require "utils/file_transfer"

# This class semi-automates the conversion of Ex Libris/Alma holdings XML to TSV
# If this runs successfully, can kick off a subsequent `phctl scrub ...`
# The code:
# - Downloads .xml (not attested) and .tar.gz (attested) files from the member's Dropbox to temp location
# - Extracts and renames the downloaded files
# - Passes the extracted files to `ExLibrisHoldingsXmlParser`
# - Uploads the resulting TSV files back up to the member's Dropbox
#
# See the `phctl convert-xml` command.
# It is intended to be run in the foreground (no Sidekiq)
#
# Example:
#   `ExLibrisHoldings.new(organization: "umich").run`

class ExLibrisHoldings
  attr_reader :file_transfer, :organization, :remote_directory

  # remote_directory is for testing/debugging
  def initialize(organization:, remote_directory: nil)
    @organization = organization
    @remote_directory = remote_directory || DataSources::DirectoryLocator.for(:remote, organization).holdings_current
    @file_transfer = Utils::FileTransfer.new
    @seq = 0
  end

  def run
    Services.logger.info "Running org #{organization}."
    if candidates.size.zero?
      Services.logger.warn "No XML files for #{organization} at #{remote_directory}, bailing out"
      return
    end

    xml_files = []
    candidates.each do |candidate|
      Services.logger.info "downloading XML #{candidate}"
      downloaded_file = download(file_h: candidate)
      xml_files << extract(path: downloaded_file)
    end
    parser = ExLibrisHoldingsXmlParser.new(
      organization: organization,
      files: xml_files,
      output_dir: local_directory
    )
    Services.logger.info "running parser with inputs #{xml_files}"
    parser.run
    # Hash `Symbol` -> `File` with keys :mon and :ser
    parsed_files = parser.output_files
    Services.logger.info "parser outputs: #{parser.output_files}"
    parsed_files.each_key do |key|
      Services.logger.info "uploading TSV #{parsed_files[key].path} to remote dir #{remote_directory}"
      upload(file: parsed_files[key].path)
    end
    Services.logger.info "cleaning up local directory #{local_directory}"
  rescue => err
    Services.logger.error err
    raise err
  ensure
    cleanup
  end

  # Remove temporary directory after upload
  def cleanup
    # force = true to ignore exceptions if tempdir hasn't been created yet
    FileUtils.remove_entry(local_directory, true)
    @local_directory = nil
  end

  # Upload the converted tsv files to remote directory
  def upload(file:)
    file_transfer.upload(file, remote_directory)
  end

  # XML files, either text or .tar.gz
  # Returns an Array of lsjson Hashes
  def candidates
    return @candidates if @candidates

    # Return new (as in not in old) files
    remote_files = file_transfer.lsjson(remote_directory)
    # Include in new_files only those remote_files whose name is not in old_files.
    @candidates = []
    remote_files.each do |f|
      # Ignore subdirectories no matter what they're named
      next if f["IsDir"]
      if f["Name"].end_with?(".tar.gz", ".xml")
        @candidates << f
      end
    end

    @candidates
  end

  # Downloads candidate (given as lsjson hash) to temporary location.
  # Returns that path as a String
  def download(file_h:)
    remote_file = File.join(remote_directory, file_h["Path"])
    file_transfer.download(remote_file, local_directory)

    # Return the path to the downloaded file
    File.join(local_directory, File.split(remote_file).last)
  end

  # Extracts a single XML file from a .tar.gz submission and returns its path.
  # If the input is an XML file, just return its path.
  def extract(path:)
    return path if path.end_with?(".xml")

    # List the files in the archive. There better be only one.
    file_list = list_tar(tar_path: path)
    if file_list.count != 1
      raise "unexpected contents for #{path}: #{file_list}"
    end

    # Avoid silly edge cases trying to find the correct name for the extracted XML files.
    # The component file can have a goofy name like "ORG institution code_hathi_monographs_new".
    # The XML parser doesn't care if there are intermingled `mon` and `ser` records --
    # it takes care of the partitioning. We could name the extracted files "a" and "b",
    # but for semi-transparency try to choose a name with a guess as to contents (mon vs ser),
    # and with sequence number to keep the second file from clobbering the first.
    mon_ser = file_list.first.match?(/ser/) ? "ser" : "mon"
    seq_suffix = sprintf("%08d", @seq += 1)
    output = File.join(
      local_directory,
      "#{organization}_#{mon_ser}_#{seq_suffix}.xml"
    )

    Services.logger.info("extract_tar(tar_path: #{path}, file_name: #{file_list.first}, destination_path: #{output})")
    extract_tar(tar_path: path, file_name: file_list.first, destination_path: output)
    output
  end

  def local_directory
    @local_directory ||= Dir.mktmpdir("exlibris_")
  end

  private

  TAR_EXE_PATH = "/usr/bin/tar"

  # List the files in a .tar.gz file
  def list_tar(tar_path:)
    stdout, stderr, status = Open3.capture3(TAR_EXE_PATH, "-tzPf", tar_path)
    if !status.success?
      raise "could not list contents of tar file #{tar_path}: status #{status}: stderr #{stderr}"
    end

    stdout.split("\n")
  end

  # Extract named file `file_name` from the .tar.gz archive at `tar_path`
  # to a new file at `destination_path`.
  # Uses the path to `tar` explicitly to bypass shell expansion
  # since `file_name` is tainted.
  def extract_tar(tar_path:, file_name:, destination_path:)
    status = nil
    stderr_s = ""

    File.open(destination_path, "w") do |destination_file|
      Open3.popen3(TAR_EXE_PATH, "-xzf", tar_path, file_name, "-O") do |stdin, stdout, stderr, wait_thr|
        stdin.close
        err_reader = Thread.new {
          stderr.read
        }
        out_reader = Thread.new {
          loop do
            bytes = stdout.readpartial(4096)
            destination_file.print bytes
            destination_file.flush
          rescue EOFError
            break
          end
        }
        stderr_s = err_reader.value
        out_reader.join
        status = wait_thr.value
      end
    end

    if !status.success? || File.size(destination_path).zero?
      raise "could not extract #{file_name} from #{tar_path} to #{destination_path}: status #{status}: stderr #{stderr_s}"
    end
  end
end
