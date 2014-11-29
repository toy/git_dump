require 'spec_helper'
require 'git_dump'
require 'tmpdir'

describe GitDump do
  def with_env(hash)
    saved = Hash[hash.map{ |key, _| [key, ENV[key]] }]
    begin
      hash.each{ |key, value| ENV[key] = value }
      yield
    ensure
      saved.each{ |key, value| ENV[key] = value }
    end
  end

  ADD_ENV = {
    'GIT_AUTHOR_NAME' => 'rspec',
    'GIT_AUTHOR_EMAIL' => 'rspec@test',
    'GIT_COMMITTER_NAME' => 'rspec',
    'GIT_COMMITTER_EMAIL' => 'rspec@test',
  }

  around do |example|
    with_env(ADD_ENV, &example)
  end

  DATAS = {
    :text => "\r\n\r\nline\nline\rline\r\nline\n\rline\r\n\r\n",
    :binary => 256.times.sort_by{ rand }.pack('C*'),
  }

  describe :new do
    let(:tmp_dir){ Dir.mktmpdir }
    let(:path){ File.join(tmp_dir, 'dump') }
    after{ FileUtils.remove_entry_secure tmp_dir }

    it 'initializes with bare git repo' do
      system('git', 'init', '-q', '--bare', path)
      expect(GitDump.new(path).git_dir).to eq(path)
    end

    it 'initialize with full git repo' do
      system('git', 'init', '-q', path)
      expect(GitDump.new(path).git_dir).to eq(File.join(path, '.git'))
    end

    it 'creates bare git repo' do
      dump = GitDump.new path, :create => true
      Dir.chdir path do
        expect(`git rev-parse --git-dir`.strip).to eq('.')
        expect(`git rev-parse --is-bare-repository`.strip).to eq('true')
      end
      expect(dump.git_dir).to eq(path)
    end

    it 'creates full git repo' do
      dump = GitDump.new path, :create => :non_bare
      Dir.chdir path do
        expect(`git rev-parse --git-dir`.strip).to eq('.git')
        expect(`git rev-parse --is-bare-repository`.strip).to eq('false')
      end
      expect(dump.git_dir).to eq(File.join(path, '.git'))
    end

    it 'raises if dump does not exist and not asked to create' do
      expect{ GitDump.new path }.to raise_error GitDump::Repo::InitException
    end

    it 'raises if path is a file' do
      File.open(path, 'w'){}
      expect{ GitDump.new path }.to raise_error GitDump::Repo::InitException
    end

    it 'raises if dump is a directory but not a git repository' do
      Dir.mkdir(path)
      expect{ GitDump.new path }.to raise_error GitDump::Repo::InitException
    end
  end

  describe 'versions' do
    let(:tmp_dir){ Dir.mktmpdir }
    let(:dump){ GitDump.new File.join(tmp_dir, 'dump'), :create => true }
    after{ FileUtils.remove_entry_secure tmp_dir }

    it 'returns empty list for empty repo' do
      expect(dump.versions).to be_empty
    end

    it 'creates and reads version' do
      builder = dump.new_version
      builder['string/x'] = 'test a'
      builder.store('stringio/x', StringIO.new('test b'), 0644)
      builder.store('io/x', File.open(__FILE__), 0755)
      builder.store_from('path/x', __FILE__)
      built = builder.commit

      reinit_dump = GitDump.new(dump.git_dir)

      expect(reinit_dump.versions.length).to eq(1)

      version = reinit_dump.versions.first

      expect(version.id).to eq(built.id)

      expect(version['string/x'].read).to eq('test a')
      expect(version['stringio/x'].read).to eq('test b')
      expect(version['io/x'].read).to eq(File.read(__FILE__))
      expect(version['path/x'].read).to eq(File.read(__FILE__))
      expect(version['should/not/be/there']).to be_nil
    end

    it 'returns path and name' do
      builder = dump.new_version
      builder['a/b/c'] = 'test'

      %w[
        a
        a/b
        a/b/c
      ].each do |path|
        expect(builder[path].path).to eq(path)
        expect(builder[path].name).to eq(path.split('/').last)
      end
    end

    it 'cleans paths' do
      builder = dump.new_version
      builder['//aa//fa//'] = 'test a'

      expect(builder['//aa//fa//'].read).to eq('test a')
      expect(builder['aa/fa//'].read).to eq('test a')
      expect(builder['aa/fa'].read).to eq('test a')
    end

    it 'replaces branches' do
      builder = dump.new_version
      builder['a/a/a/a'] = 'test a'
      builder['a/a/a/b'] = 'test b'
      builder['a/a'] = 'hello'

      expect(builder['a/a/a/a']).to be_nil
      expect(builder['a/a/a/b']).to be_nil
      expect(builder['a/a'].read).to eq('hello')
    end

    DATAS.each do |type, data|
      it "does not change #{type} data" do
        builder = dump.new_version
        builder['a'] = data

        expect(builder['a'].read).to eq(data)
      end
    end

    describe :traversing do
      let(:version) do
        builder = dump.new_version
        builder['c/c/c'] = 'c\c\c'
        builder['a'] = 'a'
        builder['b/a'] = 'b\a'
        builder['b/b'] = 'b\b'
        builder
      end

      def recursive_path_n_read(o)
        o.each_recursive.map do |entry|
          [entry.path, entry.read]
        end
      end

      it 'traverses entries recursievely' do
        expect(recursive_path_n_read(version)).to match_array([
          %w[a a],
          %w[b/a b\a],
          %w[b/b b\b],
          %w[c/c/c c\c\c],
        ])

        expect(recursive_path_n_read(version['b'])).to match_array([
          %w[b/a b\a],
          %w[b/b b\b],
        ])

        expect(recursive_path_n_read(version['c'])).to match_array([
          %w[c/c/c c\c\c],
        ])

        expect(recursive_path_n_read(version['c/c'])).to match_array([
          %w[c/c/c c\c\c],
        ])
      end

      it 'traverses level' do
        expect(version.each.map(&:path)).to match_array(%w[a b c])

        expect(version['b'].each.map(&:path)).to match_array(%w[b/a b/b])

        expect(version['c'].each.map(&:path)).to eq(%w[c/c])

        expect(version['c/c'].each.map(&:path)).to eq(%w[c/c/c])
      end
    end

    describe :write_to do
      DATAS.each do |type, data|
        it "writes back #{type} data" do
          builder = dump.new_version
          builder['a'] = data

          path = File.join(tmp_dir, 'file')
          builder['a'].write_to(path)

          expect(File.open(path, 'rb', &:read)).to eq(data)
        end
      end

      [0644, 0755].each do |mode|
        it "sets mode to #{mode.to_s(8)}" do
          builder = dump.new_version
          builder.store('a', 'test', mode)

          path = File.join(tmp_dir, 'file')
          builder['a'].write_to(path)

          expect(File.stat(path).mode & 0777).to eq(mode)
        end
      end
    end

    describe :exchange do
      let(:other_dump) do
        GitDump.new File.join(tmp_dir, 'other'), :create => true
      end

      let(:built) do
        builder = dump.new_version
        builder['a'] = 'b'
        builder.commit
      end

      def check_received_version
        expect(other_dump.versions.length).to eq(1)

        version = other_dump.versions.first
        expect(version.id).to eq(built.id)
        expect(version.each_recursive.map do |entry|
          [entry.path, entry.read]
        end).to eq([%w[a b]])
      end

      it 'pushes version' do
        built.push(other_dump.git_dir)

        check_received_version
      end

      it 'fetches version' do
        other_dump.fetch(dump.git_dir, built.id)

        check_received_version
      end
    end

    it 'removes version' do
      builder = dump.new_version
      builder['a'] = 'b'
      built = builder.commit

      expect(dump.versions.length).to eq(1)

      built.remove

      expect(dump.versions).to be_empty
    end
  end
end
