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
    # Set +debug+ to true to log all git calls and responses
    attr_accessor :debug
    # The standard +logger+ for debugging git calls - this defaults to a plain STDOUT logger
    attr_accessor :logger
    def log(str)
      logger.debug { str }
    end
  end
  self.debug = false
  @logger ||= ::Logger.new(STDOUT)
  
  VERSION = '0.8.3'
end
