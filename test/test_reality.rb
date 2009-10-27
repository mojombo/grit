require File.dirname(__FILE__) + '/helper'

# class TestTreeRecursion < Test::Unit::TestCase
#   def test_
#     r = Repo.new("/Users/tom/dev/god")
#     t = r.tree("HEAD")
#
#     recurse(t)
#   end
#
#   def recurse(tree, indent = "")
#     tree.contents.each do |c|
#       # puts "#{indent}#{c.name} (#{c.id})"
#       recurse(c, indent + "  ") if c.kind_of?(Tree)
#     end
#   end
# end