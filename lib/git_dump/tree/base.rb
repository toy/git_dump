require 'git_dump/path_object'
require 'git_dump/entry'

class GitDump
  class Tree < PathObject
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
  end
end
