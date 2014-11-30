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

      # Add blob for entries to repository, return sha
      # Each entry is a hash with following keys:
      #   :type => :blob or :tree
      #   :name => name string
      #   :sha  => sha of content
      #   :mode => last three octets of mode
      def treeify(entries)
        @treefier ||= git('mktree', '--batch').popen('r+')
        entries.map do |entry|
          values = normalize_entry(entry).values_at(:mode, :type, :sha, :name)
          line = format("%06o %s %s\t%s", *values)
          @treefier.puts line
        end
        @treefier.puts
        @treefier.gets.chomp
      end

      # Return pipe with contents of blob identified by sha
      def blob_pipe(sha, &block)
        git('cat-file', 'blob', sha).popen('rb', &block)
      end

      # Return contents of blob identified by sha
      def blob_read(sha)
        blob_pipe(sha, &:read)
      end

      # Ruturn path to temp file with contents of blob identified by sha
      # for moving to path
      def blob_unpack_tmp(sha, path)
        dir = File.dirname(path)
        temp_name = git('unpack-file', sha, :chdir => dir).capture.strip
        File.join(dir, temp_name)
      end

      # Read tree at sha returning list of entries
      # Each entry is a hash like one for treeify
      def tree_entries(sha)
        git('ls-tree', sha).stripped_lines.map do |line|
          if (m = /^(\d{6}) (blob|tree) ([0-9a-f]{40})\t(.*)$/.match(line))
            {
              :mode => m[1].to_i(8),
              :type => m[2].to_sym,
              :sha => m[3],
              :name => m[4],
            }
          else
            fail "Unexpected: #{line}"
          end
        end
      end

      # Remove tag with name id
      def remove_tag(id)
        args = %W[tag --delete #{id}]
        args << {:no_stdout => true}
        git(*args).run
      end

      # Receive tag with name id from repo at url
      # Use :progress => true to show progress
      def fetch(url, id, options = {})
        transfer(:fetch, url, id, options)
      end

      # Send tag with name id to repo at url
      # Use :progress => true to show progress
      def push(url, id, options = {})
        transfer(:push, url, id, options)
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

    private

      def normalize_entry(entry)
        out = {
          :type => entry[:type].to_sym,
          :name => entry[:name].to_s,
          :sha => entry[:sha].to_s,
        }

        base_mode = out[:type] == :tree ? 0o040_000 : 0o100_000
        out[:mode] = (entry[:mode] || 0) & 0777 | base_mode

        unless out[:sha] =~ /\A[0-9a-f]{40}\z/
          fail "Expected sha1 hash, got #{out[:sha]}"
        end

        out
      end

      def transfer(command, url, id, options)
        ref = "refs/tags/#{id}"
        args = %W[#{command} --no-tags #{url} #{ref}:#{ref}]
        args << '--quiet' unless options[:progress]
        git(*args).run
      end

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
