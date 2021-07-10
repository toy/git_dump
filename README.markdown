[![Gem Version](https://img.shields.io/gem/v/git_dump?logo=rubygems)](https://rubygems.org/gems/git_dump)
[![Build Status](https://img.shields.io/github/workflow/status/toy/git_dump/check/master?logo=github)](https://github.com/toy/git_dump/actions/workflows/check.yml)
[![Code Climate](https://img.shields.io/codeclimate/maintainability/toy/git_dump?logo=codeclimate)](https://codeclimate.com/github/toy/git_dump)
[![Depfu](https://img.shields.io/depfu/toy/git_dump)](https://depfu.com/github/toy/git_dump)
[![Inch CI](https://inch-ci.org/github/toy/git_dump.svg?branch=master)](https://inch-ci.org/github/toy/git_dump)

# git_dump

Distributed versioned store using git.

## Installation

```sh
gem install git_dump
```

## Usage

Init:

```rb
dump = GitDump.new('dump.git', :create => true)
```

Create version:

```rb
version = dump.new_version
version['a/b/c'] = 'string'
version.store('b/c/d', StringIO.new('string'), 0o644)
version.store('d/e', File.open('path'), 0o755)
version.store_from('e/f', 'path')
version.commit(:tags => 'test')
```

Read version:

```rb
version = dump.versions.last
version['a/b/c'].open{ |f| f.read }
version['a/b/c'].read
version['a/b/c'].write_to('new_path')

version.each do |path_object|
  path_object.path
end

version.each_recursive do |entry|
  entry.read
end
```

Versions:

```rb
dump.versions.each do |version|
  puts [version.id, version.time, version.commit_time].join(' ')
end

dump.versions.first.remove
```

Remote (url in any syntax supported by git including local paths):

```rb
ids = GitDump.remote_version_ids(url)

dump.versions.last.push(url)

dump.fetch(url, ids.first)
```

## Copyright

Copyright (c) 2012-2019 Ivan Kuchin. See LICENSE.txt for details.
