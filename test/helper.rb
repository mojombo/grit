require File.join(File.dirname(__FILE__), *%w[.. lib grit])

require 'bundler/setup'
require 'test/unit'
require 'mocha'

GRIT_REPO = ENV["GRIT_REPO"] || File.expand_path(File.join(File.dirname(__FILE__), '..'))

include Grit

def fixture(name)
  File.read(File.join(File.dirname(__FILE__), 'fixtures', name))
end

def absolute_project_path
  File.expand_path(File.join(File.dirname(__FILE__), '..'))
end

def jruby?
  defined?(RUBY_ENGINE) && RUBY_ENGINE =~ /jruby/
end
