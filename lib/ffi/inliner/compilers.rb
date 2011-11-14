module FFI; module Inliner

class Compiler
  attr_reader :name

  def self.check_and_create(fm = nil, libraries = nil)
    compiler = new(fm, libraries)

    unless compiler.exists?
      raise "can't find compiler #{compiler.class}"
    else
      compiler
    end
  end

  def initialize(files = nil, libraries = nil)
    @files     = files
    @libraries = libraries

    @name = cmd.split.reject { |p| [?', 'sh', '-c'].include? p }.first
  end

  def function(code)
    code
  end

  def compile
    puts 'running:' + cmd if $VERBOSE

    raise "compile error! See #{@files.log_fn}" unless system(cmd)
  end

  private
  def libs
    @libraries.inject { |str, lib| str << "-l#{lib} " } if @libraries
  end
end

end; end

require 'ffi/inliner/compilers/tcc'
require 'ffi/inliner/compilers/gcc'
require 'ffi/inliner/compilers/gxx'
