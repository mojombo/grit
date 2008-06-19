$:.unshift File.dirname(__FILE__) # For use/testing when no gem is installed

# core
require 'fileutils'
require 'time'

# stdlib
require 'timeout'

# third party
require 'rubygems'
require 'mime/types'
require 'open4'
require 'digest/sha1'

# internal requires
require 'grit/lazy'
require 'grit/errors'
require 'grit/git-ruby'
require 'grit/git'
require 'grit/ref'
require 'grit/commit'
require 'grit/commit_stats'
require 'grit/tree'
require 'grit/blob'
require 'grit/actor'
require 'grit/diff'
require 'grit/config'
require 'grit/repo'
require 'grit/index'
require 'grit/status'


module Grit
  class << self
    attr_accessor :debug
    attr_accessor :use_git_ruby
  end
  
  self.debug = false
  self.use_git_ruby = true
  
  VERSION = '0.8.2'
end
