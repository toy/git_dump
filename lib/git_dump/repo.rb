begin
  require 'git_dump/repo/rugged'
rescue LoadError
  require 'git_dump/repo/git'
end
require 'git_dump/cmd'
require 'git_dump/version'
require 'git_dump/version/builder'

class GitDump
  # Main class: create/initialize repository, find versions, provide interface
  # to git
  class Repo
    include defined?(Rugged) ? Rugged : Git

    attr_reader :path

    def initialize(path, options)
      @path = path
      resolve(path, options)
    end

    # New version builder
    def new_version
      Version::Builder.new(self)
    end

    # List of versions
    def versions
      Version.list(self)
    end

    # List remote version (tag) ids
    def remote_version_ids(url)
      remote_tag_names(url)
    end

    def inspect
      "#<#{self.class} path=#{path}>"
    end
  end
end
