require 'rugged'
require 'git_dump/repo/git'

class GitDump
  class Repo
    # Interface to git using libgit2 through rugged
    module Rugged
      include Git

      def self.included(base)
        base.extend(ClassMethods)
      end

      # Add blob for content to repository, return sha
      def data_sha(content)
        if content.respond_to?(:read)
          ::Rugged::Blob.from_io(repo, content)
        else
          ::Rugged::Blob.from_buffer(repo, content)
        end
      end

      # Add blob for content at path to repository, return sha
      def path_sha(path)
        ::Rugged::Blob.from_disk(repo, path)
      end

      # Add blob for entries to repository, return sha
      # Each entry is a hash with following keys:
      #   :type => :blob or :tree
      #   :name => name string
      #   :sha  => sha of content
      #   :mode => last three octets of mode
      def treeify(entries)
        builder = ::Rugged::Tree::Builder.new
        entries.map do |entry|
          entry = normalize_entry(entry)
          builder << {
            :type => entry[:type],
            :name => entry[:name],
            :oid => entry[:sha],
            :filemode => entry[:mode],
          }
        end
        builder.write(repo)
      end

      # Return size of object identified by sha
      def size(sha)
        ::Rugged::Object.new(repo, sha).size
      end

      # Return contents of blob identified by sha
      # If io is specified, then content will be written to io
      def blob_read(sha, io = nil)
        if io
          super(sha, io)
        else
          ::Rugged::Object.new(repo, sha).content
        end
      end

      # Read tree at sha returning list of entries
      # Each entry is a hash like one for treeify
      def tree_entries(sha)
        object = repo.lookup(sha)
        tree = object.type == :tree ? object : object.tree
        tree.map do |entry|
          {
            :type => entry[:type],
            :name => entry[:name],
            :sha => entry[:oid],
            :mode => entry[:filemode],
          }
        end
      end

      # Return list of entries per tag ref
      # Each entry is a hash with following keys:
      #   :sha => tag or commit sha
      #   :name => ref name
      def tag_entries
        repo.tags.map do |tag|
          {
            :name => tag.name,
            :sha => tag.target.oid,
            :author_time => tag.target.author[:time],
            :commit_time => tag.target.committer[:time],
            :tag_message => tag.annotation && tag.annotation.message,
            :commit_message => tag.target.message,
          }
        end
      end

    private

      def repo
        @repo ||= ::Rugged::Repository.new(path)
      end
    end
  end
end
