# require File.join(File.dirname(__FILE__), *%w[.. lib grit])
# include Grit
# 
# def recurse(tree, indent = "")
#   tree.contents.each do |c|
#     case c
#       when Tree
#         # puts "#{indent}#{c.name} (#{c.id})"
#         recurse(c, indent + "  ")
#     end
#   end
# end
# 
# 10.times do
#   r = Repo.new("/Users/tom/dev/god")
#   t = r.tree
# 
#   recurse(t)
# end

500.times { puts `git --git-dir /Users/tom/dev/god/.git ls-tree master` }