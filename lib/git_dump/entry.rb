class GitDump
  # Entry at path
  class Entry
    attr_reader :repo, :path, :sha, :mode
    def initialize(repo, path, sha, mode)
      @repo, @path, @sha, @mode = repo, path, sha, mode & 0777
    end

    # Pipe for reading data
    def open(&block)
      repo.git('cat-file', 'blob', sha).popen('rb', &block)
    end

    # Data
    def read
      open(&:read)
    end

    # Write to path
    def write_to(path)
      dir = File.dirname(path)
      temp_name = repo.git('unpack-file', sha, :chdir => dir).capture.strip
      temp_path = File.join(dir, temp_name)
      File.chmod(mode, temp_path)
      File.rename(temp_path, path)
    end

    def inspect
      "#<#{self.class} sha=#{@sha} mode=#{format '%03o', @mode}>"
    end
  end
end
