class GitDump
  # Base class for Tree, Tree::Builder and Entry
  class PathObject
    attr_reader :repo, :path, :name
    def initialize(repo, dir, name)
      @repo = repo
      @path = dir ? "#{dir}/#{name}" : name if name
      @name = name
    end
  end
end
