require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

begin
  require 'rubygems'
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "grit"
    s.rubyforge_project = "grit"
    s.summary = "Grit is a Ruby library for extracting information from a git repository in an object oriented manner."
    s.email = "tom@mojombo.com"
    s.homepage = "http://github.com/mojombo/grit"
    s.description = "Grit is a Ruby library for extracting information from a git repository in an object oriented manner."
    s.authors = ["Tom Preston-Werner", "Scott Chacon"]
    s.files = FileList["[A-Z]*.*", "lib/**/*"]
    s.add_dependency('mime-types', '>= 1.15')
    s.add_dependency('diff-lcs', '>= 1.1.2')
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/test_*.rb'
  t.verbose = false
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'grit'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'rake/contrib/sshpublisher'
  namespace :rubyforge do

    desc "Release gem and RDoc documentation to RubyForge"
    task :release => ["rubyforge:release:gem", "rubyforge:release:docs"]

    namespace :release do
      desc "Publish RDoc to RubyForge."
      task :docs => [:rdoc] do
        config = YAML.load(
            File.read(File.expand_path('~/.rubyforge/user-config.yml'))
        )

        host = "#{config['username']}@rubyforge.org"
        remote_dir = "/var/www/gforge-projects/grit/"
        local_dir = 'rdoc'

        Rake::SshDirPublisher.new(host, remote_dir, local_dir).upload
      end
    end
  end
rescue LoadError
  puts "Rake SshDirPublisher is unavailable or your rubyforge environment is not configured."
end

task :default => :test

# custom

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
