require 'git_dump/path_object'

class GitDump
  # Entry at path
  class Entry < PathObject
    attr_reader :sha, :mode
    def initialize(repo, dir, name, sha, mode)
      super(repo, dir, name)
      @sha, @mode = sha, (mode & 0o100).zero? ? 0o644 : 0o755
    end

    # Get size
    def size
      @size ||= repo.size(sha)
    end

    # Pipe for reading data
    def open(&block)
      repo.blob_pipe(sha, &block)
    end

    # Data
    def read
      repo.blob_read(sha)
    end

    # Write to path
    def write_to(path)
      repo.blob_unpack(sha, path, mode)
    end

    def inspect
      "#<#{self.class} sha=#{@sha} mode=#{format '%03o', @mode}>"
    end
  end
end
