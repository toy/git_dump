require 'git_dump/git'
require 'git_dump/version'

class GitDump
  # Main class: create/initialize repository, find versions, provide interface
  # to git
  class Repo
    # Exception during initialization
    class InitException < StandardError; end

    attr_reader :git_dir

    def initialize(path, options)
      resolve(path, options)
    end

    # Construct git command specifying `--git-dir=git_dir`
    def git(command, *args)
      Git.new("--git-dir=#{git_dir}", command, *args)
    end

    # New version builder
    def new_version
      Version::Builder.new(self)
    end

    # List of versions
    def versions
      git('show-ref', '--tags').stripped_lines.map do |line|
        if (m = %r!^([0-9a-f]{40}) refs/tags/(.*)$!.match(line))
          Version.new(self, m[2], m[1])
        else
          fail "Unexpected: #{line}"
        end
      end
    rescue Command::Failure => e
      if Command.child_status.exitstatus == 1
        []
      else
        raise e
      end
    end

    # Receive version with id from repo at url
    # Use :progress => true to show progress
    def fetch(url, id, options = {})
      ref = "refs/tags/#{id}"
      args = %W[fetch --no-tags #{url} #{ref}:#{ref}]
      args << '--quiet' unless options[:progress]
      git(*args).run
    end

    def data_sha(content)
      @data_sha_command ||= git(*%w[hash-object -w --no-filters --stdin])
      @data_sha_command.popen('r+') do |f|
        if content.respond_to?(:read)
          f.write(content.read(4096)) until content.eof?
        else
          f.write(content)
        end
        f.close_write
        f.read.chomp
      end
    end

    def path_sha(path)
      @path_sha_pipe ||=
        git(*%w[hash-object -w --no-filters --stdin-paths]).popen('r+')
      @path_sha_pipe.puts(path)
      @path_sha_pipe.gets.chomp
    end

    def treeify(lines)
      @treefier ||= git('mktree', '--batch').popen('r+')
      @treefier.puts lines
      @treefier.puts
      @treefier.gets.chomp
    end

    def inspect
      "#<#{self.class} git_dir=#{git_dir}>"
    end

  private

    def resolve(path, options)
      create(path, options) unless File.exist?(path)

      unless File.directory?(path)
        fail InitException, "#{path} is not a directory"
      end

      begin
        options = {:chdir => path, :no_stderr => true}
        relative = Git.new('rev-parse', '--git-dir', options).capture.strip
      rescue Command::Failure => e
        raise InitException, e.message, e.backtrace
      end

      @git_dir = File.expand_path(relative, path)
    end

    def create(path, options)
      unless options[:create]
        fail InitException, "#{path} does not exist and got no :create option"
      end

      bare_arg = options[:create] != :non_bare ? '--bare' : '--no-bare'
      begin
        Git.new('init', '-q', bare_arg, path, :no_stderr => true).run
      rescue Command::Failure => e
        raise InitException, e.message, e.backtrace
      end
    end
  end
end
