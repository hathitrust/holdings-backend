require "services"
Services.mongo!

# Loads entire clusters, given as JSON files.
# This is mostly intended for dev/test purposes.
# Use with care -- IF AT ALL?! -- in prod.
#
# Usage:
# loader = Loader::ClusterLoader.new
# loader.load(filename)
# loader.load_array([{x}, {y}, ... {z}])
# loader.load_hash({x})
# ... or via phctl:
# $ bundle exec ruby bin/phctl.rb load cluster_file <filename>

module Loader
  class ClusterLoader
    attr_reader :attempted_files, :attempted_docs, :success_docs, :fail_docs

    def initialize
      @attempted_files = 0
      @attempted_docs = 0
      @success_docs = 0
      @fail_docs = 0
    end

    def load(filename)
      @attempted_files += 1
      Services.logger.info("Loading JSON file #{filename}")
      docs = JSON.parse(File.read(filename))
      load_array(docs)
    end

    def load_array(array)
      array.each do |hash|
        load_hash(hash)
      end
    end

    def load_hash(hash)
      @attempted_docs += 1
      # Clean input of $oid's, because they don't insert well.
      hash.delete("_id")
      sections = ["ht_items", "holdings", "commitments", "ocn_resolutions"]
      sections.each do |section|
        if hash.key?(section)
          hash[section].each do |subsection|
            if subsection.key?("_id")
              subsection.delete("_id")
            end
          end
        end
      end
      Cluster.collection.insert_one(hash)
      @success_docs += 1
    rescue Mongo::Error::OperationFailure => err
      Services.logger.warn(err.message)
      @fail_docs += 1
    rescue BSON::String::IllegalKey => err
      Services.logger.warn(err.message)
      @fail_docs += 1
    end

    def stats
      [
        "Files attempted:#{attempted_files}",
        "total docs:#{attempted_docs}",
        "success:#{success_docs}",
        "fail:#{fail_docs}"
      ].join(", ")
    end
  end
end
