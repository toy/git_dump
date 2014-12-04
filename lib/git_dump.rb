require 'git_dump/repo'

require 'forwardable'
require 'securerandom'

# Main interface
class GitDump
  extend Forwardable

  # Initialize using existing repositiory
  # use `:create => true` or `:create => :bare` to create bare repo if missing
  # or `:create => :non_bare` for non bare one
  def initialize(path, options = {})
    @repo = Repo.new(path, options)
  end

  def_delegators :@repo, *[
    :path,
    :new_version,
    :versions,
    :fetch,
    :gc,
  ]

  class << self
    # List remote version ids
    def remote_version_ids(url)
      Repo.remote_version_ids(url)
    end
  end

  # hostname as returned by `hostname` or `unknow`
  def self.hostname
    @hostname ||= begin
      hostname = `hostname`.chomp
      hostname.empty? ? 'unknown' : hostname
    end
  end

  # From 1.9 securerandom.rb, to replace with SecureRandom.uuid
  def self.uuid
    ary = SecureRandom.random_bytes(16).unpack('NnnnnN')
    ary[2] = (ary[2] & 0x0fff) | 0x4000
    ary[3] = (ary[3] & 0x3fff) | 0x8000
    format '%08x-%04x-%04x-%04x-%04x%08x', *ary
  end
end
