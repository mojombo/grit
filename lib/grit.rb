$:.unshift File.dirname(__FILE__) # For use/testing when no gem is installed

# core
require 'fileutils'
require 'time'

# stdlib
require 'timeout'
require 'logger'
require 'digest/sha1'


if defined? RUBY_ENGINE && RUBY_ENGINE == 'jruby'
  require 'open3'
elsif RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|bccwin/
  require 'win32/open3'
else
  require 'open3_detach'
end

# third party
require 'rubygems'
begin
  gem "mime-types", ">=0"
  require 'mime/types'
rescue Gem::LoadError => e
  puts "WARNING: Gem LoadError: #{e.message}"
end

# ruby 1.9 compatibility
require 'grit/ruby1.9'

# internal requires
require 'grit/lazy'
require 'grit/errors'
require 'grit/git-ruby'
require 'grit/git' unless defined? Grit::Git
require 'grit/ref'
require 'grit/tag'
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
require 'grit/submodule'
require 'grit/blame'
require 'grit/merge'


module Grit
  class << self
    # Set +debug+ to true to log all git calls and responses
    attr_accessor :debug
    attr_accessor :use_git_ruby
    # The standard +logger+ for debugging git calls - this defaults to a plain STDOUT logger
    attr_accessor :logger
    def log(str)
      logger.debug { str }
    end
  end
  self.debug = false
  self.use_git_ruby = true

  @logger ||= ::Logger.new(STDOUT)

  def self.version
    yml = YAML.load(File.read(File.join(File.dirname(__FILE__), *%w[.. VERSION.yml])))
    "#{yml[:major]}.#{yml[:minor]}.#{yml[:patch]}"
  end
end
