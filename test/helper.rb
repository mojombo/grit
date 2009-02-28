require File.join(File.dirname(__FILE__), *%w[.. lib grit])

require 'rubygems'
require 'test/unit'
gem "mocha", ">=0"
require 'mocha'

GRIT_REPO = File.join(File.dirname(__FILE__), *%w[..])

include Grit

def fixture(name)
  File.read(File.join(File.dirname(__FILE__), 'fixtures', name))
end

def absolute_project_path
  File.expand_path(File.join(File.dirname(__FILE__), '..'))
end