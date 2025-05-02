require "clusterable/ht_item"
require "overlap/cluster_overlap"
require "services"
require "sinatra"
require "solr_record"

class HoldingsAPI < Sinatra::Base
  set :show_exceptions, ENV["show_sinatra_exceptions"] || false
  no_matching_data_error = {"application_error" => "no matching data"}.to_json

  get "/v1/ping" do
    "pong"
  end

  # Answers the question: can organization access item_id?
  get "/v1/item_access" do
    # ArgumentError if missing organization / item_id.
    validate_params(params: params, required: ["organization", "item_id"])

    organization = params["organization"]
    item_id = params["item_id"]

    ht_item = Clusterable::HtItem.find(item_id: item_id)
    overlap_record = Overlap::ClusterOverlap.overlap_record(organization, ht_item)

    return_doc = {
      "copy_count" => overlap_record.copy_count,
      "format" => ht_item.cluster.format,
      "n_enum" => ht_item.n_enum,
      "ocns" => ht_item.ocns.sort
    }
    return_doc.to_json
  end

  # Answers the question: which organization have holdings that match item_id?
  get "/v1/item_held_by" do
    # ArgumentError if missing item_id.
    validate_params(params: params, required: ["item_id"])
    item_id = params["item_id"]
    constraint = params["constraint"]

    ht_item = Clusterable::HtItem.find(item_id: item_id)
    cluster = ht_item.cluster

    organizations = case constraint
    when nil
      cluster.organizations_in_cluster
    when "brlm"
      cluster.access_counts.select { |org, count| count > 0 }.keys.sort
    else
      raise ArgumentError, "Invalid constraint."
    end

    return_doc = {"organizations" => organizations}
    return_doc.to_json
  end

  # POST a solr record in JSON format with the id, oclc_search, and ht_json fields; returns:
  #
  # [
  #   {
  #     item_id: "test.id1",
  #     organizations: ["org1", "org2", ...]
  #   },
  #   {
  #     item_id: "test.id2",
  #     organizations: ["org1", ...]
  #   }
  # ]
  #
  post "/v1/record_held_by" do
    json = request.body.read
    r = SolrRecord.from_json(json)

    Overlap::ClusterOverlap
      .new(r.cluster)
      .group_by { |o| o.ht_item.item_id }
      .map do |item_id, overlaps|
        {
          "item_id" => item_id,
          "organizations" => overlaps.map(&:org)
        }
      end.to_json
  end

  error ArgumentError do
    status 404
    {"application_error" => env["sinatra.error"].message}.to_json
  end

  error Sequel::NoMatchingRow do
    status 404
    no_matching_data_error
  end

  error do
    Services.logger.error env["sinatra.error"].message
    status 404
    "Error"
  end

  private

  def validate_params(params:, required:)
    argument_errors = []
    required.each do |param_name|
      if !params.key?(param_name) || params[param_name].empty?
        argument_errors << "missing required param: #{param_name}"
      end
    end
    if argument_errors.any?
      raise ArgumentError, argument_errors.join("; ")
    end
  end
end
