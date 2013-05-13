if ENV['TRAVIS']
  require 'coveralls'
  Coveralls.wear!
end

require File.join(File.dirname(__FILE__), *%w[.. lib grit])

require 'rubygems'
require 'test/unit'
require 'mocha/setup'
require 'pry'

REPOS_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', 'repos'))
GRIT_REPO = ENV["GRIT_REPO"] || File.join(REPOS_PATH, 'grit')

if File.exists?(GRIT_REPO)
  puts "Using repo from #{GRIT_REPO}"
else
  puts 'Unpacking repo for tests...'
  puts `tar -C #{REPOS_PATH} -xvf #{GRIT_REPO}.tar.gz`
end

include Grit

def fixture(name)
  File.read(File.join(File.dirname(__FILE__), 'fixtures', name))
end

def absolute_project_path
  GRIT_REPO
end

def jruby?
  defined?(RUBY_ENGINE) && RUBY_ENGINE =~ /jruby/
end
