require 'git_dump/command'

class GitDump
  # Running git commands
  class Git < Command
    def initialize(*args)
      super(:git, *args)
    end
  end
end
