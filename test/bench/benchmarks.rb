require 'fileutils'
require 'benchmark'
require 'rubygems'
require 'ruby-prof'
require 'memcache'
require 'pp'

gem 'grit', '=0.7.0' 
#require '../../lib/grit'

def main
  @wbare = File.expand_path(File.join('../../', 'test', 'dot_git'))
  
  in_temp_dir do
    #result = RubyProf.profile do

      git = Grit::Repo.new('.')
      puts Grit::VERSION
      #Grit::GitRuby.cache_client = MemCache.new 'localhost:11211', :namespace => 'grit'
      #Grit.debug = true
    
      #pp Grit::GitRuby.cache_client.stats 
    
      commit1 = '5e3ee1198672257164ce3fe31dea3e40848e68d5'
      commit2 = 'ca8a30f5a7f0f163bbe3b6f0abf18a6c83b0687a'
    
      Benchmark.bm(8) do |x|
            
        run_code(x, 'packobj') do
          @commit = git.commit('5e3ee1198672257164ce3fe31dea3e40848e68d5')
          @tree = git.tree('cd7422af5a2e0fff3e94d6fb1a8fff03b2841881')
          @blob = git.blob('4232d073306f01cf0b895864e5a5cfad7dd76fce')
          @commit.parents[0].parents[0].parents[0]
        end

        run_code(x, 'commits 1') do
          git.commits.size
        end
              
        run_code(x, 'commits 2') do
          log = git.commits('master', 15)
          log.size
          log.size
          log.first
          git.commits('testing').map { |c| c.message }
        end

        run_code(x, 'big revlist') do
          c = git.commits('master', 200)
        end

        run_code(x, 'log') do
          log = git.log('master')
          log.size
          log.size
          log.first
        end

        run_code(x, 'diff') do
          c = git.diff(commit1, commit2)
        end

        run_code(x, 'commit-diff') do
          c = git.commit_diff(commit1)
        end

        run_code(x, 'heads') do
          c = git.heads.collect { |b| b.commit.id }
        end

       # run_code(x, 'config', 100) do
       #   c = git.config['user.name']
       #   c = git.config['user.email']
       # end

        #run_code(x, 'commit count') do
        #  c = git.commit_count('testing')
        #end


      end
    #end

    #printer = RubyProf::FlatPrinter.new(result)
    #printer.print(STDOUT, 0)
    
  end


end


def run_code(x, name, times = 30)
    x.report(name.ljust(12)) do
      for i in 1..times do
        yield i
      end
    end
  
  #end
  
  # Print a graph profile to text
end

def new_file(name, contents)
  File.open(name, 'w') do |f|
    f.puts contents
  end
end


def in_temp_dir(remove_after = true)
  filename = 'git_test' + Time.now.to_i.to_s + rand(300).to_s.rjust(3, '0')
  tmp_path = File.join("/tmp/", filename)
  FileUtils.mkdir(tmp_path)
  Dir.chdir tmp_path do
    FileUtils.cp_r(@wbare, File.join(tmp_path, '.git'))
    yield tmp_path
  end
  puts tmp_path
  #FileUtils.rm_r(tmp_path) if remove_after
end

main()

##pp Grit::GitRuby.cache_client.stats 
