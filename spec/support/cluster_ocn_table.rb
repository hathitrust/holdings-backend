RSpec.shared_context "with cluster ocns table" do
  let(:cluster_ocns_table) { Services.holdings_db[:cluster_ocns] }
  before(:each) { cluster_ocns_table.truncate }

  # import a data structure like
  # {
  #   cid1 => [ ocn1, ocn2, ocn3 ],
  #   cid2 => [ ocn4, ocn5 ]
  #   ...
  # }
  def import_cluster_ocns(cluster_ocns)
    data = []
    cluster_ocns.each do |cluster_id, ocns|
      ocns.each do |ocn|
        data << [cluster_id, ocn]
      end
    end

    cluster_ocns_table.import([:cluster_id, :ocn], data)
  end
end
