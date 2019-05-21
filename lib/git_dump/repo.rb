# frozen_string_literal: true

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

    class << self
      # List remote version ids
      alias_method :remote_version_ids, :remote_tag_names
    end

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

    def inspect
      "#<#{self.class} path=#{path}>"
    end
  end
end
