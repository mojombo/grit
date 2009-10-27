# require File.dirname(__FILE__) + '/helper'
#
# class TestReal < Test::Unit::TestCase
#   def setup
#     `rm -fr /Users/tom/dev/sandbox/grittest.git`
#     `git --git-dir=/Users/tom/dev/sandbox/grittest.git init`
#     @repo = Repo.new('/Users/tom/dev/sandbox/grittest.git')
#   end
#
#   def test_real
#     Grit.debug = true
#
#     index = @repo.index
#     index.add('foo/bar/baz.txt', 'hello!')
#     index.add('foo/qux/bam.txt', 'world!')
#
#     puts index.commit('first commit')
#   end
# end