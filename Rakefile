#! /usr/bin/env ruby
require 'rake'

task :default => :test

task :test do
	Dir.chdir 'spec/ffi-inliner'

	sh 'rspec inliner_spec.rb --color --format specdoc'
end
