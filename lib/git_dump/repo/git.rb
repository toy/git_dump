class GitDump
  class Repo
    # Interface to git using system calls and pipes
    module Git
      # Exception during initialization
      class InitException < StandardError; end

      # Construct git command specifying git-dir
      def git(command, *args)
        Cmd.git("--git-dir=#{@git_dir}", command, *args)
      end

      # Add blob for content to repository, return sha
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

      # Add blob for content at path to repository, return sha
      def path_sha(path)
        @path_sha_pipe ||=
          git(*%w[hash-object -w --no-filters --stdin-paths]).popen('r+')
        @path_sha_pipe.puts(path)
        @path_sha_pipe.gets.chomp
      end

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
