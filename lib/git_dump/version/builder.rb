require 'git_dump/version'
require 'git_dump/version/base'
require 'git_dump/tree/builder'

class GitDump
  class Version
    # Creating version
    class Builder
      include Base

      attr_reader :repo
      def initialize(repo)
        @repo = repo
        @tree = Tree::Builder.new(repo, nil, nil)
      end

      # Store data `content` with mode `mode` at `path`
      # Pass `nil` as content to remove
      def store(path, content, mode = 0644)
        tree.store(path, content, mode)
      end
      alias_method :[]=, :store

      # Store data from `from` with mode `mode` (by default file mode) at `path`
      def store_from(path, from, mode = nil)
        tree.store_from(path, from, mode)
      end

      # Create commit and tag it, returns Version instance
      # Options:
      #   :time - set version time (tag and commit)
      #   :tags - list of strings to associate with this version
      def commit(options = {})
        time = options[:time] || Time.now
        tags = Array(options[:tags]).join(',')

        name_parts = [
          time.utc.strftime('%Y-%m-%d_%H-%M-%S'),
          GitDump.hostname,
          tags,
          GitDump.uuid,
        ]

        commit_sha = repo.commit(tree.sha, :date => time)
        tag_name = repo.tag(commit_sha, name_parts, :date => time)
        repo.gc(:auto => true)

        Version.new(repo, tag_name, commit_sha)
      end

      def inspect
        "#<#{self.class} tree=#{tree.inspect}>"
      end

    private

      attr_reader :tree
    end
  end
end
