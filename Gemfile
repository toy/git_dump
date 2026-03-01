# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rugged', '>= 0.22' if ENV.fetch('DRIVER', nil) == 'rugged'

if RUBY_VERSION >= '4'
  gem 'benchmark'
end
