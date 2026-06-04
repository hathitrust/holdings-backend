# frozen_string_literal: true

require "securerandom"

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
      xml_files << extract(file: downloaded_file)
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
    # Return new (as in not in old) files
    remote_files = file_transfer.lsjson(remote_directory)
    # Include in new_files only those remote_files whose name is not in old_files.
    new_files = []
    remote_files.each do |f|
      # Ignore subdirectories no matter what they're named
      next if f["IsDir"]
      if f["Name"].end_with?(".tar.gz", ".xml")
        new_files << f
      end
    end

    new_files
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
  def extract(file:)
    return file if file.end_with?(".xml")

    # List the files in the archive. There better be only one.
    file_list = `tar -tzPf #{file}`.split("\n")
    if file_list.count != 1
      raise "unexpected contents for #{file}: #{file_list}"
    end

    # Avoid silly edge cases trying to find the correct name for the extracted XML files.
    # The component file can have a goofy name like "ORG institution code_hathi_monographs_new".
    # The XML parser doesn't care if there are intermingled `mon` and `ser` records --
    # it takes care of the partitioning. We could name the extracted files "a" and "b",
    # but for semi-transparency try to choose a name with a guess as to contents (mon vs ser),
    # and with random characters to keep the second file from clobbering the first.
    mon_ser = file_list.first.match?(/ser/) ? "ser" : "mon"
    random_suffix = SecureRandom.urlsafe_base64(8)
    output = File.join(
      local_directory,
      "#{organization}_#{mon_ser}_#{random_suffix}.xml"
    )
    cmd = "tar -xzf #{file} '#{file_list.first}' -O > #{output}"
    Services.logger.info(cmd)
    system(cmd, exception: true)
    output
  end

  def local_directory
    @local_directory ||= Dir.mktmpdir("exlibris_")
  end
end
