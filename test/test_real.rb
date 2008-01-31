# require File.dirname(__FILE__) + '/helper'
# 
# class TestReal < Test::Unit::TestCase
#   def setup
#     @repo = Repo.new('/Users/tom/dev/sandbox/ruby-on-rails-tmbundle')
#   end
#   
#   def test_real
#     # Grit.debug = true
#     
#     p @repo.commits
#     
#     # p (@repo.tree/'Syntaxes/Ruby on Rails.plist').data
#     # p @repo.tree('master', ['Snippets/rea.plist']).contents.first
#     p @repo.tree('master', ['Syntaxes/Ruby on Rails.plist']).contents.first
#   end
# end