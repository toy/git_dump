class GitDump
  class Repo
    # Interface to git using system calls and pipes
    module Git
      # Exception during initialization
      class InitException < StandardError; end

    private

      def resolve(path, options)
        create(path, options) unless File.exist?(path)

        unless File.directory?(path)
          fail InitException, "#{path} is not a directory"
        end

        begin
          options = {:chdir => path, :no_stderr => true}
          relative = Cmd.git('rev-parse', '--git-dir', options).capture.strip
        rescue Cmd::Failure => e
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
          Cmd.git('init', '-q', bare_arg, path, :no_stderr => true).run
        rescue Cmd::Failure => e
          raise InitException, e.message, e.backtrace
        end
      end
    end
  end
end
