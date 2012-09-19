require 'git_dump/tree'
require 'git_dump/entry'

class GitDump
  # Reading version
  class Version
    # Common methods in Version and Builder
    module Base
      def [](path)
        tree[path]
      end

      def each(&block)
        tree.each(&block)
      end

      def each_recursive(&block)
        tree.each_recursive(&block)
      end
    end

    # Creating version
    class Builder
      include Base

      attr_reader :repo
      def initialize(repo)
        @repo = repo
        @tree = Tree::Builder.new(repo, nil)
      end

      def add(path, content, mode = 0644)
        add_sha(path, repo.data_sha(content), mode)
      end
      alias_method :[]=, :add

      def add_file(path, from, mode = nil)
        add_sha(path, repo.path_sha(from), mode || File.stat(from).mode)
      end

      def commit
        sha = repo.git('commit-tree', tree.sha).popen('r+') do |f|
          # f.puts description
          f.close_write
          f.read.chomp
        end
        tag_name = [
          Time.now.utc.strftime('%Y-%m-%d_%H-%M-%S'),
          GitDump.hostname,
          GitDump.uuid,
        ].map do |component|
          cleanup_ref_component(component)
        end.join('/')
        repo.git('tag', tag_name, sha).run
        Version.new(repo, tag_name, sha)
      end

      def inspect
        "#<#{self.class} tree=#{tree.inspect}>"
      end

    private

      attr_reader :tree

      def add_sha(path, sha, mode)
        tree[path] = Entry.new(repo, path, sha, mode)
      end

      def cleanup_ref_component(component)
        component.gsub(/[^a-zA-Z0-9\-_,]+/, '_')
      end
    end

    include Base

    attr_reader :repo, :id, :sha
    def initialize(repo, id, sha)
      @repo, @id, @sha = repo, id, sha
    end

    def inspect
      "#<#{self.class} id=#{@id} sha=#{@sha} tree=#{@tree.inspect}>"
    end

  private

    def tree
      @tree ||= Tree.new(repo, nil, sha)
    end
  end
end
