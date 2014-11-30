require 'git_dump/version/base'
require 'git_dump/tree'

class GitDump
  # Reading version
  class Version
    include Base

    attr_reader :repo, :id, :sha
    def initialize(repo, id, sha)
      @repo, @id, @sha = repo, id, sha
    end

    # Send this version to repo at url
    # Use :progress => true to show progress
    def push(url, options = {})
      repo.push(url, id, options)
    end

    # Remove this version
    def remove
      args = %W[tag --delete #{id}]
      args << {:no_stdout => true}
      repo.git(*args).run
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
