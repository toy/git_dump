# git_dump

Distributed versioned store using git.

## Installation

```sh
gem install git_dump
```

## Usage

Create version:

```rb
dump = GitDump.new('dump.git', :create => true)
version = dump.new_version
version['a/b/c'] = 'string'
version.add('b/c/d', StringIO.new('string'), 0644)
version.add('d/e', File.open('path'), 0755)
version.add_file('e/f', 'path')
version.commit
```

Read version:

```rb
dump = GitDump.new('dump.git')
version = dump.versions.last
version['a/b/c'].pipe{ |f| f.read }
version['a/b/c'].read

version.each do |entry|
  entry.path
end

version.each_recursive do |entry|
  entry.read
end
```

## Copyright

Copyright (c) 2012 Ivan Kuchin. See LICENSE.txt for details.
