require 'git_dump/repo/git'
require 'git_dump/cmd'
require 'git_dump/version'
require 'git_dump/version/builder'

class GitDump
  # Main class: create/initialize repository, find versions, provide interface
  # to git
  class Repo
    include Git

    attr_reader :path

    def initialize(path, options)
      @path = path
      resolve(path, options)
    end

    # Construct git command specifying `--git-dir=git_dir`
    def git(command, *args)
      Cmd.git("--git-dir=#{@git_dir}", command, *args)
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
    rescue Cmd::Failure => e
      if Cmd.child_status.exitstatus == 1
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

    # Run garbage collection
    # Use :auto => true to run only if GC is required
    # Use :aggressive => true to run GC more aggressively
    def gc(options = {})
      args = %w[gc --quiet]
      args << '--auto' if options[:auto]
      args << '--aggressive' if options[:aggressive]
      git(*args).run
    end

    def treeify(lines)
      @treefier ||= git('mktree', '--batch').popen('r+')
      @treefier.puts lines
      @treefier.puts
      @treefier.gets.chomp
    end

    def inspect
      "#<#{self.class} path=#{path}>"
    end
  end
end
