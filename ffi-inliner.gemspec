Kernel.load 'lib/ffi/inliner/version.rb'

Gem::Specification.new {|s|
  s.name         = 'ffi-inliner'
  s.version      = FFI::Inliner::Version
  s.author       = 'Andrea Fazzi'
  s.email        = 'andrea.fazzi@alcacoop.it'
  s.homepage     = 'http://github.com/remogatto/ffi-inliner'
  s.platform     = Gem::Platform::RUBY
  s.summary      = 'Mix C in (J)Ruby and gulp it on the fly!'

  s.files         = `git ls-files`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ['lib']

  s.add_dependency 'ffi', '>=0.4.0'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
}
