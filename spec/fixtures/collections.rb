# frozen_string_literal: true

def mock_collections
  HTCollections.new(
    "TEST" => HTCollection.new(collection: "TEST", content_provider_cluster: "test",
                               responsible_entity: "test", original_from_inst_id: "test",
                               billing_entity: "test"),
    "PU" => HTCollection.new(collection: "PU", content_provider_cluster: "upenn",
                             responsible_entity: "upenn", original_from_inst_id: "upenn",
                             billing_entity: "upenn"),
    "MIU" => HTCollection.new(collection: "MIU", content_provider_cluster: "umich",
                              responsible_entity: "umich", original_from_inst_id: "umich",
                              billing_entity: "umich"),
    "HVD" => HTCollection.new(collection: "HVD", content_provider_cluster: "harvard",
                              responsible_entity: "harvard", original_from_inst_id: "harvard",
                              billing_entity: "harvard"),
    "OKS" => HTCollection.new(collection: "OKS", content_provider_cluster: "okstate",
                              responsible_entity: "okstate", original_from_inst_id: "okstate",
                              billing_entity: "okstate"),
    "KEIO" => HTCollection.new(collection: "KEIO", content_provider_cluster: "keio",
                               responsible_entity: "hathitrust", original_from_inst_id: "keio",
                               billing_entity: "hathitrust")
  )
end
