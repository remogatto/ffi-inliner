#! /usr/bin/env ruby
require 'rake'

task :default => :test

task :test do
	Dir.chdir 'spec'

	sh 'rspec inliner_spec.rb --color --format doc'
end
