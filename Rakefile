require 'rake/gempackagetask'
require 'rake/rdoctask'

$: << "#{File.dirname(__FILE__)}/lib"

spec = Gem::Specification.new { |s|
	s.platform = Gem::Platform::RUBY

	s.author = "Pete Elmore"
	s.email = "1337p337@gmail.com"
	s.files = Dir["{lib,doc,bin,ext}/**/*"].delete_if {|f| 
		/\/rdoc(\/|$)/i.match f
	} + %w(Rakefile)
	s.require_path = 'lib'
	s.has_rdoc = true
	s.extra_rdoc_files = Dir['doc/*'].select(&File.method(:file?))
	s.extensions << 'ext/extconf.rb' if File.exist? 'ext/extconf.rb'
	Dir['bin/*'].map(&File.method(:basename)).map(&s.executables.method(:<<))

	s.name = 'git-ui'
	s.summary = 'Hacky attempt at a workable UI for git, modeled slightly on '\
		'darcs.'
	s.homepage = "http://debu.gs/#{s.name}"
	%w(colorize).each &s.method(:add_dependency)
	s.version = '0.0.0'
}

Rake::RDocTask.new(:doc) { |t|
	t.main = 'doc/README'
	t.rdoc_files.include 'lib/**/*.rb', 'doc/*', 'bin/*', 'ext/**/*.c', 
		'ext/**/*.rb'
	t.options << '-S' << '-N'
	t.rdoc_dir = 'doc/rdoc'
}

Rake::GemPackageTask.new(spec) { |pkg|
	pkg.need_tar_bz2 = true
}
desc "Cleans out the packaged files."
task(:clean) {
	FileUtils.rm_rf 'pkg'
}

task(:install => :package) { 
	g = "pkg/#{spec.name}-#{spec.version}.gem"
	system "sudo gem install -l #{g}"
}

task(:irb) {
	exec "irb -Ilib -r#{spec.name}"
}
