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

      # Create commit and tag it, returns Version instance
      # Options:
      #   :time - set version time (tag and commit)
      #   :tags - list of strings to associate with this version
      def commit(options = {})
        time = options[:time] || Time.now
        tags = Array(options[:tags]).join(',')

        time_s = time.strftime('%s %z')
        env = {
          'GIT_AUTHOR_DATE' => time_s,
          'GIT_COMMITTER_DATE' => time_s,
        }

        sha = repo.git('commit-tree', tree.sha, :env => env).popen('r+') do |f|
          # f.puts description
          f.close_write
          f.read.chomp
        end
        tag_name = [
          time.utc.strftime('%Y-%m-%d_%H-%M-%S'),
          GitDump.hostname,
          GitDump.uuid,
          tags,
        ].map do |component|
          cleanup_ref_component(component)
        end.reject(&:empty?).join('/')
        repo.git('tag', tag_name, sha, :env => env).run
        repo.gc(:auto => true)
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

    # Send this version to repo at url
    # Use :progress => true to show progress
    def push(url, options = {})
      ref = "refs/tags/#{id}"
      args = %W[push --no-tags #{url} #{ref}:#{ref}]
      args << '--quiet' unless options[:progress]
      repo.git(*args).run
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
      @tree ||= Tree.new(repo, nil, sha)
    end
  end
end
