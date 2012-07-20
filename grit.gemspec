Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'

  s.name              = 'grit'
  s.version           = '2.5.0'
  s.date              = '2012-04-22'
  s.rubyforge_project = 'grit'

  s.summary     = "Ruby Git bindings."
  s.description = "Grit is a Ruby library for extracting information from a git repository in an object oriented manner."

  s.authors  = ["Tom Preston-Werner", "Scott Chacon"]
  s.email    = 'tom@github.com'
  s.homepage = 'http://github.com/mojombo/grit'

  s.require_paths = %w[lib]

  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README.md LICENSE]

  s.add_dependency('posix-spawn', "~> 0.3.6")
  s.add_dependency('mime-types', "~> 1.15")
  s.add_dependency('diff-lcs', "~> 1.1")

  s.add_development_dependency('mocha')

  # = MANIFEST =
  s.files = %w[
    API.txt
    History.txt
    LICENSE
    PURE_TODO
    README.md
    Rakefile
    benchmarks.rb
    benchmarks.txt
    examples/ex_add_commit.rb
    examples/ex_index.rb
    grit.gemspec
    lib/grit.rb
    lib/grit/actor.rb
    lib/grit/blame.rb
    lib/grit/blob.rb
    lib/grit/commit.rb
    lib/grit/commit_stats.rb
    lib/grit/config.rb
    lib/grit/diff.rb
    lib/grit/errors.rb
    lib/grit/git-ruby.rb
    lib/grit/git-ruby/commit_db.rb
    lib/grit/git-ruby/git_object.rb
    lib/grit/git-ruby/internal/file_window.rb
    lib/grit/git-ruby/internal/loose.rb
    lib/grit/git-ruby/internal/pack.rb
    lib/grit/git-ruby/internal/raw_object.rb
    lib/grit/git-ruby/repository.rb
    lib/grit/git.rb
    lib/grit/index.rb
    lib/grit/lazy.rb
    lib/grit/merge.rb
    lib/grit/ref.rb
    lib/grit/repo.rb
    lib/grit/ruby1.9.rb
    lib/grit/status.rb
    lib/grit/submodule.rb
    lib/grit/tag.rb
    lib/grit/tree.rb
  ]
  # = MANIFEST =

  s.test_files = s.files.select { |path| path =~ /^test\/test_.*\.rb/ }
end
