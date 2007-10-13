require File.dirname(__FILE__) + '/helper'

class TestTreeRecursion < Test::Unit::TestCase
  def test_
    r = Repo.new("/Users/tom/dev/god")
    t = r.tree("HEAD")
    
    recurse(t)
  end
  
  def recurse(tree, indent = "")
    tree.contents.each do |c|
      case c
        when Tree
          # puts "#{indent}#{c.name} (#{c.id})"
          recurse(c, indent + "  ")
      end
    end
  end
end