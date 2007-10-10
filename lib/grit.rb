$:.unshift File.dirname(__FILE__)     # For use/testing when no gem is installed

# core

# stdlib

# internal requires
require 'grit/errors'
require 'grit/head'
require 'grit/grit'

class Grit
  VERSION = '1.0.0'
end