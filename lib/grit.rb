$:.unshift File.dirname(__FILE__) # For use/testing when no gem is installed

# core
require 'fileutils'

# stdlib

# third party
require 'rubygems'
require 'mime/types'

# internal requires
require 'grit/lazy'
require 'grit/errors'
require 'grit/git'
require 'grit/head'
require 'grit/commit'
require 'grit/tree'
require 'grit/blob'
require 'grit/actor'
require 'grit/diff'
require 'grit/repo'

module Grit
  class << self
    attr_accessor :debug
  end
  
  self.debug = false
  
  VERSION = '0.7.0'
end