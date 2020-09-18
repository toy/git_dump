# encoding: UTF-8
# frozen_string_literal: true

require 'git_dump'
require 'tmpdir'

describe GitDump do
  around do |example|
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      example.run
    end
  end
  let(:tmp_dir){ @tmp_dir }

  content = {
    :text => "\r\n\r\nline\nline\rline\r\nline\n\rline\r\n\r\n",
    :binary => 256.times.sort_by{ rand }.pack('C*'),
  }.freeze

  describe :new do
    let(:path){ File.join(tmp_dir, 'dump') }

    it 'initializes with bare git repo' do
      system('git', 'init', '-q', '--bare', path)
      expect(GitDump.new(path).path).to eq(path)
    end

    it 'initializes with full git repo' do
      system('git', 'init', '-q', path)
      expect(GitDump.new(path).path).to eq(path)
    end

    it 'creates bare git repo' do
      dump = GitDump.new path, :create => true
      Dir.chdir path do
        expect(`git rev-parse --git-dir`.strip).to eq('.')
        expect(`git rev-parse --is-bare-repository`.strip).to eq('true')
      end
      expect(dump.path).to eq(path)
    end

    it 'creates full git repo' do
      dump = GitDump.new path, :create => :non_bare
      Dir.chdir path do
        expect(`git rev-parse --git-dir`.strip).to eq('.git')
        expect(`git rev-parse --is-bare-repository`.strip).to eq('false')
      end
      expect(dump.path).to eq(path)
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

  context do
    let(:dump){ GitDump.new File.join(tmp_dir, 'dump'), :create => true }

    it 'returns empty list for empty repo versions' do
      expect(dump.versions).to be_empty
    end

    it 'creates version for every commit' do
      builder = dump.new_version
      3.times{ builder.commit }

      expect(dump.versions.length).to eq(3)
    end

    it 'builds id from time, hostname and uuid' do
      allow(GitDump).to receive(:hostname).and_return('ivans')
      time = Time.utc(2000, 10, 20, 12, 34, 56)

      builder = dump.new_version
      built = builder.commit(:time => time)

      expect(built.id).to match(%r{
        \A
          2000-10-20_12-34-56
        /
          ivans
        /
          (?i:
            [0-9a-f]{8}-
            [0-9a-f]{4}-
            4[0-9a-f]{3}-
            [89ab][0-9a-f]{3}-
            [0-9a-f]{12}
          )
        \z
      }x)
    end

    [
      'hello,world,foo,bar_',
      %w[hello world foo bar_],
      'hello,world,foo,bar!@#$%^&*()',
    ].each do |tags|
      it 'puts tags in name' do
        builder = dump.new_version
        built = builder.commit(:tags => tags)

        expect(built.id.split('/')).to include('hello,world,foo,bar_')
      end
    end

    it 'sets and reads version time' do
      time = Time.parse('2000-10-20 12:34:56')

      builder = dump.new_version
      built = builder.commit(:time => time)

      expect(built.time).to eq(time)
      expect(dump.versions.first.time).to eq(time)
    end

    it 'reads commit time' do
      builder = dump.new_version
      from = Time.at(Time.now.to_i) # round down to second
      built = builder.commit(:time => Time.parse('2000-10-20 12:34:56'))
      to = Time.now

      expect(built.commit_time).to be_between(from, to)
      expect(dump.versions.first.commit_time).to be_between(from, to)
    end

    it 'sets and reads version annotation' do
      message = content[:text] + File.read(__FILE__)

      builder = dump.new_version
      built = builder.commit(:annotation => message)

      expect(built.annotation).to eq(message)
      expect(dump.versions.first.annotation).to eq(message)
    end

    it 'sets and reads version description' do
      message = content[:text] + File.read(__FILE__)

      builder = dump.new_version
      built = builder.commit(:description => message)

      expect(built.description).to eq(message)
      expect(dump.versions.first.description).to eq(message)
    end

    it 'creates and reads version' do
      builder = dump.new_version
      builder['string/x'] = 'test a'
      builder.store('stringio/x', StringIO.new('test b'), 0o644)
      builder.store('io/x', File.open(__FILE__), 0o755)
      builder.store_from('path/x', __FILE__)
      built = builder.commit

      reinit_dump = GitDump.new(dump.path)

      expect(reinit_dump.versions.length).to eq(1)

      version = reinit_dump.versions.first

      expect(version.id).to eq(built.id)

      expect(version['string/x'].read).to eq('test a')
      expect(version['stringio/x'].read).to eq('test b')
      expect(version['io/x'].read).to eq(File.open(__FILE__, 'rb', &:read))
      expect(version['path/x'].read).to eq(File.open(__FILE__, 'rb', &:read))
      expect(version['should/not/be/there']).to be_nil
    end

    it 'removes version' do
      builder = dump.new_version
      builder['a'] = 'b'
      built = builder.commit

      expect(dump.versions.length).to eq(1)

      built.remove

      expect(dump.versions).to be_empty
    end

    it 'returns path and name for trees and entries' do
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

    it 'returns size for entries' do
      datas = [
        '',
        '1',
        '᚛᚛ᚉᚑᚅᚔᚉᚉᚔᚋ ᚔᚈᚔ ᚍᚂᚐᚅᚑ ᚅᚔᚋᚌᚓᚅᚐ᚜',
      ] + content.values

      builder = dump.new_version
      datas.each_with_index do |data, i|
        builder["a/path/#{i}"] = data
      end

      datas.each_with_index do |data, i|
        expect(builder["a/path/#{i}"].size).to eq(data.bytesize)
      end
    end

    it 'cleans paths' do
      builder = dump.new_version
      builder['//aa//fa//'] = 'test a'

      expect(builder['//aa//fa//'].read).to eq('test a')
      expect(builder['aa/fa//'].read).to eq('test a')
      expect(builder['aa/fa'].read).to eq('test a')
    end

    it 'replaces tree branches' do
      builder = dump.new_version
      builder['a/a/a/a'] = 'test a'
      builder['a/a/a/b'] = 'test b'
      builder['a/a'] = 'hello'

      expect(builder['a/a/a/a']).to be_nil
      expect(builder['a/a/a/b']).to be_nil
      expect(builder['a/a'].read).to eq('hello')
    end

    it 'removes entries and trees' do
      builder = dump.new_version
      builder['a/a/a'] = 'test a'
      builder['a/a/b'] = 'test b'
      builder['b/a'] = 'test c'
      builder['b/b'] = 'test d'

      builder['a/a'] = nil
      builder['b/a'] = nil

      version = builder.commit

      expect(version.each.map(&:path)).to match_array(%w[a b])

      expect(version['a'].each.map(&:path)).to be_empty

      expect(version['b'].each.map(&:path)).to match_array(%w[b/b])
    end

    content.each do |type, data|
      it "does not change #{type} data" do
        builder = dump.new_version
        builder['a'] = data

        expect(builder['a'].read).to eq(data)
      end

      it "does not change #{type} data read from file" do
        path = File.join(tmp_dir, 'file.txt')
        File.open(path, 'wb') do |f|
          f.write(data)
        end

        builder = dump.new_version
        builder.store_from('a', path)

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

      def recursive_path_n_read(obj)
        obj.each_recursive.map do |entry|
          [entry.path, entry.read]
        end
      end

      it 'traverses entries recursively' do
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
      content.each do |type, data|
        it "writes back #{type} data" do
          builder = dump.new_version
          builder['a'] = data

          path = File.join(tmp_dir, 'file')
          builder['a'].write_to(path)

          expect(File.open(path, 'rb', &:read)).to eq(data)
        end
      end

      [0o644, 0o755].each do |mode|
        it "sets mode to #{mode.to_s(8)}" do
          builder = dump.new_version
          builder.store('a', 'test', mode)

          path = File.join(tmp_dir, 'file')
          builder['a'].write_to(path)

          expect(File.stat(path).mode & 0o777).to eq(mode)
        end

        it "fixes mode to #{mode.to_s(8)}" do
          builder = dump.new_version
          builder.store('a', 'test', mode & 0o100)

          path = File.join(tmp_dir, 'file')
          builder['a'].write_to(path)

          expect(File.stat(path).mode & 0o777).to eq(mode)
        end
      end
    end

    it 'gets remote version ids' do
      builder = dump.new_version
      3.times{ builder.commit }

      expect(GitDump.remote_version_ids(dump.path)).
        to eq(dump.versions.map(&:id))
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
        built.push(other_dump.path)

        check_received_version
      end

      it 'fetches version' do
        other_dump.fetch(dump.path, built.id)

        check_received_version
      end
    end
  end
end
