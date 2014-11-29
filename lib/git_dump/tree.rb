class GitDump
  # Interface to git tree
  class Tree
    # Common methods in Tree and Builder
    module Base
      # Retrive tree or entry at path, return nil if there is nothing at path
      def [](path)
        get_at(parse_path(path))
      end

      # Iterate over every tree/entry of this tree, return enumerator if no
      # block given
      def each(&block)
        return to_enum(:each) unless block
        @entries.each do |_, entry|
          block[entry]
        end
      end

      # Iterate over all entries recursively, return enumerator if no block
      # given
      def each_recursive(&block)
        return to_enum(:each_recursive) unless block
        @entries.each do |_, entry|
          if entry.is_a?(Entry)
            block[entry]
          else
            entry.each_recursive(&block)
          end
        end
      end

    protected

      def get_at(parts)
        return unless (entry = @entries[parts.first])
        if parts.length == 1
          entry
        elsif entry.is_a?(self.class)
          entry.get_at(parts.drop(1))
        end
      end

    private

      def parse_path(path)
        path = Array(path).join('/') unless path.is_a?(String)
        path.scan(/[^\/]+/)
      end
    end

    # Creating tree
    class Builder
      include Base

      attr_reader :repo, :path
      def initialize(repo, path)
        @repo, @path = repo, path
        @entries = {}
      end

      # Store data `content` with mode `mode` at `path`
      def store(path, content, mode = 0644)
        put_at(parse_path(path), repo.data_sha(content), mode)
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
          @entries[name] =
            Entry.new(repo, path ? "#{path}/#{name}" : name, sha, mode)
        else
          unless @entries[name].is_a?(self.class)
            @entries[name] =
              self.class.new(repo, path ? "#{path}/#{name}" : name)
          end
          @entries[name].put_at(parts, sha, mode)
        end
      end
    end

    include Base

    attr_reader :repo, :path, :sha
    def initialize(repo, path, sha)
      @repo, @path, @sha = repo, path, sha
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
            Entry.new(repo, path ? "#{path}/#{name}" : name, sha, mode)
          else
            Tree.new(repo, path ? "#{path}/#{name}" : name, sha)
          end
        else
          fail "Unexpected: #{line}"
        end
      end
      entries
    end
  end
end
