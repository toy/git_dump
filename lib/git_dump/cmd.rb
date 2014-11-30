require 'shellwords'
require 'English'

class GitDump
  # Running commands using system and popen
  class Cmd
    # Non succesfull exit code
    class Failure < StandardError; end

    def self.child_status
      $CHILD_STATUS
    end

    attr_reader :args
    attr_reader :env
    attr_reader :chdir
    attr_reader :no_stdout
    attr_reader :no_stderr

    def initialize(*args)
      args = args.dup
      options = args.pop if args.last.is_a?(Hash)
      @args = args.map(&:to_s)

      return unless options

      @env = options.delete(:env).to_hash if options.key?(:env)
      @chdir = options.delete(:chdir).to_s if options.key?(:chdir)
      @no_stdout = !!options.delete(:no_stdout) if options.key?(:no_stdout)
      @no_stderr = !!options.delete(:no_stderr) if options.key?(:no_stderr)

      fail "Unknown options: #{options.inspect}" unless options.empty?
    end

    # Construct command string
    def to_s
      cmd = args.shelljoin
      if env
        env_str = env.map{ |k, v| "#{k}=#{v}" }.shelljoin
        cmd = "export #{env_str}; #{cmd}"
      end
      cmd = "cd #{chdir}; #{cmd}" if chdir
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

    def arguments
      if RUBY_VERSION < '1.9' || defined?(JRUBY_VERSION)
        to_s
      else
        options = {}
        options[:chdir] = chdir if chdir
        options[:out] = '/dev/null' if no_stdout
        options[:err] = '/dev/null' if no_stderr
        [env || {}] + args + [options]
      end
    end
  end
end
