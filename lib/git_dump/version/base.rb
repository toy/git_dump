# frozen_string_literal: true

class GitDump
  class Version
    # Common methods in Version and Builder
    module Base
      # Retrive tree or entry at path, return nil if there is nothing at path
      def [](path)
        tree[path]
      end

      # Iterate over every tree/entry at root level
      def each(&block)
        tree.each(&block)
      end

      # Iterate over all entries recursively
      def each_recursive(&block)
        tree.each_recursive(&block)
      end
    end
  end
end
