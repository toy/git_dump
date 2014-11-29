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
      repo.git('ls-tree', sha).stripped_lines.each do |line|
        if (m = /^(\d{6}) (blob|tree) ([0-9a-f]{40})\t(.*)$/.match(line))
          mode = m[1].to_i(8)
          type = m[2]
          sha = m[3]
          name = m[4]
          entries[name] = if type == 'blob'
            Entry.new(repo, path, name, sha, mode)
          else
            self.class.new(repo, path, name, sha)
          end
        else
          fail "Unexpected: #{line}"
        end
      end
      entries
    end
  end
end
