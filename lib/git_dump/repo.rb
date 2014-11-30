require 'git_dump/repo/git'
require 'git_dump/cmd'
require 'git_dump/version'
require 'git_dump/version/builder'

class GitDump
  # Main class: create/initialize repository, find versions, provide interface
  # to git
  class Repo
    include Git

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
      refs.map do |entry|
        Version.new(self, entry[:name], entry[:sha])
      end
    end

    def inspect
      "#<#{self.class} path=#{path}>"
    end
  end
end
