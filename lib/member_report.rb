# frozen_string_literal: true

require 'cluster'

# Get data from mongo to provide reports on members' holdings as they relate
# to format, overlap with ht items, etc.

class MemberReport

  def initialize(institution: nil)
    @selector = if institution.nil?
                  Cluster
                else
                  Cluster.where("holdings.organization" => institution)
                end

  end
end
