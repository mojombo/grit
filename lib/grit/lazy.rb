# Allows attributes to be declared as lazy, meaning that they won't be
# computed until they are asked for. Just mix this module in:
#
#   class Foo
#     include Lazy
#     ...
#   end
#
# To specify a lazy reader:
#
#   lazy_reader :att
#
# Then, define a method called __bake__ that computes all your lazy
# attributes:
#
#   def __bake__
#     @att = ...
#   end
#
# If you happen to have already done all the hard work, you can mark an instance
# as already baked by calling:
#
#   __baked__
#
# That's it! (Tom Preston-Werner: rubyisawesome.com)
module Lazy
  module ClassMethods
    def lazy_reader(*args)
      args.each do |arg|
        define_method(arg) do
          val = instance_variable_get("@#{arg}")
          return val if val
          self.__prebake__
          instance_variable_get("@#{arg}")
        end
      end
    end
  end
  
  def __prebake__
    return if @__baked__
    self.__bake__
    @__baked__ = true
  end
  
  def __baked__
    @__baked__ = true
  end
  
  def self.included(base)
    base.extend(ClassMethods)
  end 
end