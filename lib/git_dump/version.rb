require 'git_dump/version/base'
require 'git_dump/tree'

class GitDump
  # Reading version
  class Version
    include Base

    def self.list(repo)
      repo.tag_entries.map do |entry|
        Version.new(repo, entry[:name], entry[:sha], entry[:author_time])
      end
    end

    attr_reader :repo, :id, :sha, :time
    def initialize(repo, id, sha, time)
      @repo, @id, @sha, @time = repo, id, sha, time
    end

    # Send this version to repo at url
    # Use :progress => true to show progress
    def push(url, options = {})
      repo.push(url, id, options)
    end

    # Remove this version
    def remove
      repo.remove_tag(id)
    end

    def inspect
      "#<#{self.class} id=#{@id} sha=#{@sha} tree=#{@tree.inspect}>"
    end

  private

    def tree
      @tree ||= Tree.new(repo, nil, nil, sha)
    end
  end
end
