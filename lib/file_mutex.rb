# frozen_string_literal: true

class MutexHeldException < RuntimeError; end

# Globally control access to a resource by using a file on the filesystem.
#
# Usage: FileMutex.new(path).with_lock { do_something }
#
# If path exists, with_lock will raise MutexHeldException rather than blocking.
# If path does not exist, with_lock will create it, run the block, and then
# remove it.
class FileMutex
  attr_accessor :path

  def initialize(path)
    @path = path
  end

  def with_lock
    if File.exist?(path)
      raise MutexHeldException, "#{path} exists, cannot lock"
    else
      FileUtils.touch(path)
      yield
      FileUtils.rm(path)
    end
  end
end
