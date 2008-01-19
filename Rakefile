require 'rubygems'
require 'hoe'
require './lib/grit.rb'

Hoe.new('grit', Grit::VERSION) do |p|
  p.rubyforge_name = 'grit'
  p.author = 'Tom Preston-Werner'
  p.email = 'tom@rubyisawesome.com'
  p.summary = 'Object model interface to a git repo'
  p.description = p.paragraphs_of('README.txt', 2..2).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[2..-1].map { |u| u.strip }
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
end

desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -r ./lib/grit.rb"
end

task :coverage do
  system("rm -fr coverage")
  system("rcov test/test_*.rb")
  system("open coverage/index.html")
end

desc "Upload site to Rubyforge"
task :site do
  sh "scp -r doc/* mojombo@grit.rubyforge.org:/var/www/gforge-projects/grit"
end