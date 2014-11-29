require 'git_dump/path_object'
require 'git_dump/entry'

class GitDump
  class Tree < PathObject
    # Creating tree
    class Builder < PathObject
      include Base

      def initialize(repo, dir, name)
        super(repo, dir, name)
        @entries = {}
      end

      # Store data `content` with mode `mode` at `path`
      # Pass `nil` as content to remove
      def store(path, content, mode = 0644)
        put_at(parse_path(path), content && repo.data_sha(content), mode)
      end
      alias_method :[]=, :store

      # Store data from `from` with mode `mode` (by default file mode) at `path`
      def store_from(path, from, mode = nil)
        mode ||= File.stat(from).mode
        put_at(parse_path(path), repo.path_sha(from), mode)
      end

      def sha
        lines = @entries.map do |name, entry|
          if entry.is_a?(self.class)
            "040000 tree #{entry.sha}\t#{name}"
          else
            "100#{entry.mode.to_s(8)} blob #{entry.sha}\t#{name}"
          end
        end
        repo.treeify(lines)
      end

      def inspect
        "#<#{self.class} #{@entries.inspect}>"
      end

    protected

      def put_at(parts, sha, mode)
        name = parts.shift
        if parts.empty?
          if sha.nil?
            @entries.delete(name)
          else
            @entries[name] = Entry.new(repo, path, name, sha, mode)
          end
        else
          unless @entries[name].is_a?(self.class)
            @entries[name] = self.class.new(repo, path, name)
          end
          @entries[name].put_at(parts, sha, mode)
        end
      end
    end
  end
end
