require "rake"
require "rake/testtask"
require "rake/rdoctask"
require "rake/clean"
require "rake/gempackagetask"

task :default => [ :test ]
task :doc     => [ :appdoc ]
task :test    => [ :test_units ]

desc "generate documentation for the application"
rd = Rake::RDocTask.new("appdoc") do |rdoc|
  rdoc.rdoc_dir = "doc"
  rdoc.title    = "XMLROCS Library Documentation"
  rdoc.options << "--line-numbers"
  rdoc.options << "--inline-source"
  rdoc.options << "--charset=utf-8"
  rdoc.rdoc_files.include("README")
  rdoc.rdoc_files.include("TODO")
  rdoc.rdoc_files.include("LICENSE")
  rdoc.rdoc_files.include("lib/*.rb")
end

desc "run unit tests in test/unit"
rt = Rake::TestTask.new("test_units") do |t|
  t.libs << "test/unit"
  t.pattern = "test/test_*.rb"
  t.verbose = true
end

desc "create a ruby gem"
spec = Gem::Specification.new do |s| 
  s.name = "XMLROCS"
  s.version = "0.0.2"
  s.author = "Andreas Meingast"
  s.email = "ameingast@gmail.com"
  s.homepage = "http://yomi.at/"
  s.platform = Gem::Platform::RUBY
  s.summary = "Map XML Data into Ruby objects"
  s.files = FileList["{lib}/*", "LICENSE", "TODO", "README"].to_a
  s.require_path = "lib"
  s.autorequire = "name"
  s.test_files = FileList["{test}/test_*.rb", "{test}/fixtures/*"].to_a
  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
  s.add_dependency "hpricot"
end

Rake::GemPackageTask.new(spec) do |pkg| 
  pkg.need_tar = true 
end
