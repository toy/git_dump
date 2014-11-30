require 'git_dump/path_object'

class GitDump
  # Entry at path
  class Entry < PathObject
    attr_reader :sha, :mode
    def initialize(repo, dir, name, sha, mode)
      super(repo, dir, name)
      @sha, @mode = sha, mode & 0777
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
      temp_path = repo.blob_unpack_tmp(sha, path)
      File.chmod(mode, temp_path)
      File.rename(temp_path, path)
    end

    def inspect
      "#<#{self.class} sha=#{@sha} mode=#{format '%03o', @mode}>"
    end
  end
end
