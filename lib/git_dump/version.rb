# frozen_string_literal: true

require 'git_dump/version/base'
require 'git_dump/tree'

class GitDump
  # Reading version
  class Version
    include Base

    def self.list(repo)
      repo.tag_entries.map do |entry|
        Version.new(repo, entry[:name], entry[:sha], {
          :time => entry[:author_time],
          :commit_time => entry[:commit_time],
          :annotation => entry[:tag_message],
          :description => entry[:commit_message],
        })
      end
    end

    def self.by_id(repo, id)
      list(repo).find{ |version| version.id == id }
    end

    attr_reader :repo, :id, :sha, :time
    attr_reader :commit_time, :annotation, :description

    def initialize(repo, id, sha, attributes = {})
      fail ArgumentError, 'Expected Repo' unless repo.is_a?(Repo)

      @repo, @id, @sha = repo, id, sha
      @time = attributes[:time]
      @commit_time = attributes[:commit_time]
      @annotation = attributes[:annotation]
      @description = attributes[:description]
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
