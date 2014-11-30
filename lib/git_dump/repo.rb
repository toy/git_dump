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

    # New version builder
    def new_version
      Version::Builder.new(self)
    end

    # List of versions
    def versions
      format = '%(objectname) %(refname)'
      cmd = git('for-each-ref', "--format=#{format}", 'refs/tags')
      cmd.stripped_lines.map do |line|
        if (m = %r!^([0-9a-f]{40}) refs/tags/(.*)$!.match(line))
          Version.new(self, m[2], m[1])
        else
          fail "Unexpected: #{line}"
        end
      end
    end

    def inspect
      "#<#{self.class} path=#{path}>"
    end
  end
end
