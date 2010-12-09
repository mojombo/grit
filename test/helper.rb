require File.join(File.dirname(__FILE__), *%w[.. lib grit])

require 'rubygems'
require 'test/unit'
gem "mocha", ">=0"
require 'mocha'

# Make sure we're in the test dir, the tests expect that to be the current
# directory.
TEST_DIR  = File.join(File.dirname(__FILE__), *%w[.])
GRIT_REPO = ENV["GRIT_REPO"] || File.expand_path(File.join(File.dirname(__FILE__), '..'))

include Grit

def fixture(name)
  File.read(File.join(File.dirname(__FILE__), 'fixtures', name))
end

def absolute_project_path
  File.expand_path(File.join(File.dirname(__FILE__), '..'))
end

def testpath(path)
  File.join(TEST_DIR, path)
end

def cloned_testpath(path)
  path   = testpath(path)
  cloned = path.chomp('.git')
  FileUtils.rm_rf cloned
  Dir.chdir(File.expand_path(File.dirname(path))) do
    %x{git clone #{File.basename(path)}}
  end
  cloned
end