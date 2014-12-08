require 'shellwords'
require 'English'

class GitDump
  # Running commands using system and popen
  class Cmd
    # Non succesfull exit code
    class Failure < StandardError; end

    # Run git command
    def self.git(*args)
      new(:git, *args)
    end

    # Command arguments
    attr_reader :args

    # Environment variables to set for command
    attr_reader :env

    # Working dir for running command
    attr_reader :chdir

    # Pipe /dev/null to stdin
    attr_reader :no_stdin

    # Redirect stdout to /dev/null
    attr_reader :no_stdout

    # Redirect stderr to /dev/null
    attr_reader :no_stderr

    # Construct command, last argument can be a hash of options with keys:
    #   :env - hash of environment varibles
    #   :chdir - working dir for running command
    #   :no_stdin - pipe /dev/null to stdin
    #   :no_stdout - redirect stdout to /dev/null
    #   :no_stderr - redirect stderr to /dev/null
    def initialize(*args)
      args = args.dup
      options = args.pop if args.last.is_a?(Hash)
      @args = args.map(&:to_s)

      parse_options(options) if options
    end

    # Construct command string
    def to_s
      cmd = args.shelljoin
      if env
        env_str = env.map{ |k, v| "#{k}=#{v}" }.shelljoin
        cmd = "export #{env_str}; #{cmd}"
      end
      cmd = "cd #{chdir}; #{cmd}" if chdir
      cmd << ' < /dev/null' if no_stdin
      cmd << ' > /dev/null' if no_stdout
      cmd << ' 2> /dev/null' if no_stderr
      cmd
    end

    # Run using system
    def run
      success = system(*arguments)
      return true if success
      fail Failure, "`#{self}` failed with #{$CHILD_STATUS.exitstatus}"
    end

    # Run using popen
    def popen(mode = 'r', &block)
      if block
        result = IO.popen(arguments, mode, &block)
        return result if $CHILD_STATUS.success?
        fail Failure, "`#{self}` failed with #{$CHILD_STATUS.exitstatus}"
      else
        IO.popen(arguments, mode)
      end
    end

    # Write input to pipe and return output
    def pipe(input)
      popen(input ? 'r+' : 'r') do |f|
        if input
          f.write input
          f.close_write
        end
        f.read
      end
    end

    # Capture output
    def capture
      popen(&:read)
    end

    # Captured lines
    def stripped_lines
      capture.split(/[\n\r]+/)
    end

    def inspect
      "#<#{self.class} #{self}>"
    end

  private

    # Parse options hash, fail on unknown options
    def parse_options(options)
      @env = options.delete(:env).to_hash if options.key?(:env)
      @chdir = options.delete(:chdir).to_s if options.key?(:chdir)
      @no_stdin = !!options.delete(:no_stdin) if options.key?(:no_stdin)
      @no_stdout = !!options.delete(:no_stdout) if options.key?(:no_stdout)
      @no_stderr = !!options.delete(:no_stderr) if options.key?(:no_stderr)

      fail "Unknown options: #{options.inspect}" unless options.empty?
    end

    # For ruby < 1.9 and jruby use to_s, otherwise return args with env hash
    # prepanded and options hash appended
    def arguments
      return to_s if RUBY_VERSION < '1.9' || defined?(JRUBY_VERSION)
      options = {}
      options[:chdir] = chdir if chdir
      options[:in] = '/dev/null' if no_stdin
      options[:out] = '/dev/null' if no_stdout
      options[:err] = '/dev/null' if no_stderr
      [env || {}] + args + [options]
    end
  end
end
