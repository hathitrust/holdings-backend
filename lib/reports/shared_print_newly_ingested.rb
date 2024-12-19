require "cluster"
require "services"

# A report listing organizations (excluding the depositor) who hold newly-ingested items,
# so that the shared print officer can solicit commitments.
# Example:
#   require "reports/shared_print_newly_ingested"
#   rpt = Reports::SharedPrintNewlyIngested.new(
#     start_date: "2023-01-01",
#     ht_item_ids_file: "/some/file/somewhere.tsv"
#   )
#   rpt.run
# Phctl:
#   bash phctl.sh report shared-print-newly-ingested --start_date=x --ht_item_ids_file=y

module Reports
  class SharedPrintNewlyIngested
    attr_reader :start_date, :ht_item_ids_file
    def initialize(start_date: "2022-10-01", ht_item_ids_file: nil)
      raise "not implemented"
      @start_date = start_date
      @ht_item_ids_file = ht_item_ids_file
      validate!
    end

    def validate!
      # For the purposes of this report, any YYYY-MM-DD date
      # less than Y2K or bigger than tomorrow is not a valid date.
      tomorrow = (Time.now + 86400).strftime("%Y-%m-%d")
      unless @start_date.between?("1999-12-31", tomorrow)
        raise "@start_date #{@start_date} not a valid year?"
      end
      # File may be nil. If not, it must be an existing file.
      unless @ht_item_ids_file.nil? || File&.exist?(@ht_item_ids_file)
        raise "@ht_item_ids_file #{@ht_item_ids_file} does not exist?"
      end
    end

    # Run report and print to file.
    # Call stack:
    # run calls matching_ht_items,
    # which calls matching_clusters,
    # which calls matching_item_ids,
    # which calls matching_item_ids_from_(db|file),
    # which gets the most basic data. Add data as we go back up the call stack.
    def run
      File.open(outf, "w") do |f|
        f.puts header
        # Given ht_items and holders, format and output to file.
        matching_ht_items do |ht_item, min_time, holders|
          output = [
            ht_item.billing_entity,
            ht_item.item_id,
            ht_item.access,
            min_time,
            holders
          ]
          f.puts output.join("\t")
        end
      end
    end

    # Get full path for writing
    def outf
      dir = Settings.sp_newly_ingested_report_path || "/tmp"
      FileUtils.mkdir_p(dir)
      ymd = Time.now.strftime("%Y%m%d")
      fname = "sp_newly_ingested_report_#{ymd}.tsv"
      File.join(dir, fname)
    end

    # Get header
    def header
      [
        "contributor",
        "ht_id",
        "rights_status",
        "ingest_date",
        "holding_orgs"
      ].join("\t")
    end

    # Given clusters, get their items and holders
    def matching_ht_items
      return enum_for(:matching_ht_items) unless block_given?
      matching_clusters do |cluster, min_time|
        cluster.ht_items.each do |ht_item|
          # If single part monograph
          if ht_item.bib_fmt == "BK" && ht_item.enum_chron.empty?
            # ... fetch holders and yield
            holders = holders_minus_contributor(cluster, ht_item.billing_entity)
            yield ht_item, min_time, holders
          end
        end
      end
    end

    # Get all the orgs with holdings on a cluster, minus the declared contributor
    def holders_minus_contributor(cluster, contributor)
      cluster
        .holdings
        .map(&:organization)
        .reject { |org| org == contributor }
        .sort
        .uniq
        .join(",")
    end

    # Given item_ids, find the corresponding clusters
    def matching_clusters
      return enum_for(:matching_clusters) unless block_given?
      matching_item_ids do |ht_id, min_time|
        Cluster.where("ht_items.item_id": ht_id).each do |cluster|
          yield cluster, min_time
        end
      end
    end

    # Yields pairs of ht_id + min_time from mysql or file
    def matching_item_ids
      return enum_for(:matching_item_ids) unless block_given?
      # Ask item_ids_src which method to call
      send(item_ids_src) do |ht_id, min_time|
        yield ht_id, min_time
      end
    end

    # Which method to call for item_ids?
    def item_ids_src
      if @ht_item_ids_file.nil?
        :matching_item_ids_from_db
      else
        :matching_item_ids_from_file
      end
    end

    # Get item_id and "min_time" from mysql, these are the volumes that
    # were ingested or got their rights assigned since @start_date.
    # Relies on the rights database (mysql) and: "[...] should be a target
    # for getting via an API or something in the future." @aelkiss
    def matching_item_ids_from_db
      return enum_for(:matching_item_ids_from_db) unless block_given?
      db = Services.holdings_db
      db.run("USE ht")
      db.fetch(query, @start_date) do |row|
        yield row[:ht_id], row[:min_time]
      end
    end

    # The query string, if going via matching_item_ids_from_db
    def query
      <<~HEREDOC
        SELECT
        CONCAT(namespace, '.', id)         AS ht_id,
        MIN(DATE_FORMAT(time, "%Y-%m-%d")) AS min_time
        FROM
        rights_log
        GROUP BY
        namespace, id
        HAVING
        min_time >= ?
      HEREDOC
    end

    # For testing or caching purposes, read matching items from file rather than db.
    def matching_item_ids_from_file
      return enum_for(:matching_item_ids_from_file) unless block_given?
      File.open(@ht_item_ids_file, "r") do |inf|
        inf.each_line do |line|
          line.strip!
          ht_id, min_time = line.split("\t")
          if min_time >= @start_date
            yield ht_id, min_time
          end
        end
      end
    end
  end
end
