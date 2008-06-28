$:.unshift File.dirname(__FILE__) # For use/testing when no gem is installed

# core
require 'fileutils'
require 'time'

# stdlib
require 'timeout'
require 'logger'

# third party
require 'rubygems'
require 'mime/types'
require 'open4'

# internal requires
require 'grit/lazy'
require 'grit/errors'
require 'grit/git'
require 'grit/ref'
require 'grit/commit'
require 'grit/tree'
require 'grit/blob'
require 'grit/actor'
require 'grit/diff'
require 'grit/config'
require 'grit/repo'
require 'grit/index'

module Grit
  class << self
    attr_accessor :debug
    attr_accessor :logger
    def log(str)
      logger.debug { str }
    end
  end
  self.debug = false
  @logger ||= ::Logger.new(STDOUT)
  
  VERSION = '0.8.1'
end
