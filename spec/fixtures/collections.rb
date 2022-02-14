# frozen_string_literal: true

def mock_collections
  DataSources::HTCollections.new(
    "TEST" => DataSources::HTCollection.new(collection: "TEST", content_provider_cluster: "test",
      responsible_entity: "test", original_from_inst_id: "test",
      billing_entity: "test"),
    "PU" => DataSources::HTCollection.new(collection: "PU", content_provider_cluster: "upenn",
      responsible_entity: "upenn", original_from_inst_id: "upenn",
      billing_entity: "upenn"),
    "MIU" => DataSources::HTCollection.new(collection: "MIU", content_provider_cluster: "umich",
      responsible_entity: "umich", original_from_inst_id: "umich",
      billing_entity: "umich"),
    "KEIO" => DataSources::HTCollection.new(collection: "KEIO", content_provider_cluster: "keio",
      responsible_entity: "hathitrust", original_from_inst_id: "keio",
      billing_entity: "hathitrust"),
    "UCM" => DataSources::HTCollection.new(collection: "UCM", content_provider_cluster: "ucm",
      responsible_entity: "ucm", original_from_inst_id: "ucm",
      billing_entity: "ucm")
  )
end
