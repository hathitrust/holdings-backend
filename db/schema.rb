require 'services'

Services.database!
ActiveRecord::Schema.define(version: 0) do # rubocop:disable Metrics/BlockLength

  create_table "clusters", if_not_exists: true

  create_table "cluster_ocns", primary_key: [:ocn], if_not_exists: true do |t|
    t.references :cluster
    t.integer :ocn
  end

  create_table "holdings", if_not_exists: true do |t|
    t.integer :ocn
    t.string :organization
    t.string :local_id
    t.string :enum_chron, default: ""
    t.string :n_enum, default: ""
    t.string :n_chron, default: ""
    t.string :n_enum_chron, default: ""
    t.string :status
    t.string :condition
    t.boolean :gov_doc_flag
    t.string :mono_multi_serial
    t.datetime :date_received
    t.string :country_code
    t.float :weight
    t.string :uuid
    t.string :issn
  end


end
