# frozen_string_literal: true

# - ocn
# - local_id
# - format
# - access
# - rights
class ETASOverlap
  attr_accessor :ocn, :local_id, :item_type, :access, :rights

  def initialize(ocn:, local_id:, item_type:, access:, rights:)
    @ocn = ocn
    @local_id = local_id
    @item_type = item_type
    @access = access
    @rights = rights
  end

  def to_s
    [ocn,
     local_id,
     item_type,
     access,
     rights].join("\t")
  end
end
