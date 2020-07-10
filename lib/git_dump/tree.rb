# frozen_string_literal: true

require 'git_dump/path_object'
require 'git_dump/tree/base'
require 'git_dump/entry'

class GitDump
  # Interface to git tree
  class Tree < PathObject
    include Base

    attr_reader :sha

    def initialize(repo, dir, name, sha)
      super(repo, dir, name)
      @sha = sha
      @entries = read_entries
    end

  private

    def read_entries
      entries = {}
      repo.tree_entries(sha).each do |entry|
        entries[entry[:name]] = if entry[:type] == :tree
          self.class.new(repo, path, entry[:name], entry[:sha])
        else
          Entry.new(repo, path, entry[:name], entry[:sha], entry[:mode])
        end
      end
      entries
    end
  end
end
