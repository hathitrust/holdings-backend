# frozen_string_literal: true

require "cluster"

# Services for clustering Print Serials records
class ClusterSerial
  def initialize(serial)
    @serial = serial
  end

  def cluster
    c = Cluster.find_by(ocns: @serial[:ocns])
    if c
      c.serials << @serial
      c
    end
  end

  def move(new_cluster)
    unless new_cluster.id == @serial._parent.id
      duped_s = @serial.dup
      new_cluster.serials << duped_s
      @serial.delete
      @serial = duped_s
    end
  end

end
