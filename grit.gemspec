Gem::Specification.new do |s|
  s.name        = 'grit'
  s.version     = '2.5.1'
  s.date        = '2013-05-06'
  s.license     = 'MIT'
  s.summary     = "Ruby Git bindings."
  s.description = "Grit is a Ruby library for extracting information from a git repository in an object oriented manner. GitLab fork"
  s.authors     = ["Tom Preston-Werner", "Scott Chacon", "Dmitriy Zaporozhets", "Ranmocy Sheng"]
  s.email       = 'ranmocy@gmail.com'
  s.homepage    = 'http://github.com/ranmocy/grit'
  s.require_paths = %w[lib]
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README.md LICENSE]
  s.files = `git ls-files lib/`.split("\n")
  s.test_files = s.files.select { |path| path =~ /^test\/test_.*\.rb/ }

  s.add_dependency("charlock_holmes", "~> 0.6.9")
  s.add_dependency('posix-spawn', "~> 0.3.6")
  s.add_dependency('mime-types', "~> 1.15")
  s.add_dependency('diff-lcs', "~> 1.1")
  s.add_development_dependency('mocha')
end
