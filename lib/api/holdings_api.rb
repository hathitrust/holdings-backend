require "cluster"
require "clusterable/ht_item"
require "services"
require "sinatra"

class HoldingsAPI < Sinatra::Base
  set :show_exceptions, ENV["show_sinatra_exceptions"] || false
  no_matching_data_error = {"application_error" => "no matching data"}.to_json

  get "/v1/ping" do
    "pong"
  end

  # Answers the question: can organization access ht_id?
  get "/v1/item_access" do
    # ArgumentError if missing organization / ht_id.
    validate_params(params, ["organization", "ht_id"])

    organization = params["organization"]
    ht_id = params["ht_id"]

    ht_item = Clusterable::HtItem.find(item_id: ht_id)
    cluster = ht_item.cluster

    return_doc = {
      "copy_count" => cluster.copy_counts[organization],
      "format" => cluster.format,
      "n_enum" => ht_item.n_enum,
      "ocns" => ht_item.ocns.sort
    }
    return_doc.to_json
  end

  # Answers the question: which organization have holdings that match ht_id?
  get "/v1/item_held_by" do
    # ArgumentError if missing ht_id.
    validate_params(params, ["ht_id"])
    ht_id = params["ht_id"]

    ht_item = Clusterable::HtItem.find(item_id: ht_id)
    cluster = ht_item.cluster

    return_doc = {
      "organizations" => cluster.organizations_in_cluster
    }
    return_doc.to_json
  end

  def validate_params(params, to_validate)
    argument_errors = []
    to_validate.each do |param_name|
      if !params.key?(param_name) || params[param_name].empty?
        argument_errors << "missing param: #{param_name}"
      end
    end
    if argument_errors.any?
      raise ArgumentError, argument_errors.join("; ")
    end
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
end
