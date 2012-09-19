class GitDump
  # Interface to git tree
  class Tree
    # Common methods in Tree and Builder
    module Base
      # Access entry or tree at path
      def [](path)
        get_at(parse_path(path))
      end

      # Iterate entries/trees at one level, return enumerator if no block given
      def each(&block)
        return to_enum(:each) unless block
        @entries.each do |_, entry|
          block[entry]
        end
      end

      # Iterate every entry recursively, return enumerator if no block given
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

      def []=(path, object)
        put_at(parse_path(path), object)
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

      def put_at(parts, object)
        name = parts.first
        if parts.length == 1
          @entries[name] = object
        else
          unless @entries[name].is_a?(self.class)
            @entries[name] =
              self.class.new(repo, path ? "#{path}/#{name}" : name)
          end
          @entries[name].put_at(parts.drop(1), object)
        end
      end
    end

    include Base

    attr_reader :repo, :path, :sha
    def initialize(repo, path, sha)
      @repo, @path, @sha = repo, path, sha
      @entries = {}

      repo.git('ls-tree', sha).stripped_lines.each do |line|
        if (m = /^(\d{6}) blob ([0-9a-f]{40})\t(.*)$/.match(line))
          @entries[m[3]] = Entry.new(repo, m[3], m[2], m[1].to_i(8))
        elsif (m = /^(\d{6}) tree ([0-9a-f]{40})\t(.*)$/.match(line))
          @entries[m[3]] = Tree.new(repo, m[3], m[2])
        else
          fail "Unexpected: #{line}"
        end
      end
    end
  end
end
