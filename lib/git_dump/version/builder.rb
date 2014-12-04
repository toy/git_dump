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
      #   :annotation - tag message
      #   :description - commit message
      def commit(options = {})
        options = {:time => Time.now}.merge(options)

        commit_sha = repo.commit(tree.sha, {
          :time => options[:time],
          :message => options[:description],
        })

        tag_name = repo.tag(commit_sha, name_parts(options), {
          :time => options[:time],
          :message => options[:annotation],
        })

        repo.gc(:auto => true)

        Version.by_id(repo, tag_name)
      end

      def inspect
        "#<#{self.class} tree=#{tree.inspect}>"
      end

    private

      attr_reader :tree

      def name_parts(options)
        [
          options[:time].dup.utc.strftime('%Y-%m-%d_%H-%M-%S'),
          GitDump.hostname,
          Array(options[:tags]).join(','),
          GitDump.uuid,
        ]
      end
    end
  end
end
