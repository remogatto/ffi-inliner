module FFI

module Inliner
  def self.directory
    # the home dir gets big way too fast imho
    # @directory ||= File.expand_path(File.join('~', '.ffi-inliner'))

    require 'tmpdir'
    @directory ||= File.expand_path(File.join(Dir.tmpdir, ".ffi-inliner-#{Process.uid}"))

    if File.exists?(@directory) && !File.directory?(@directory)
      FileUtils.rm_rf @directory
    end

    if !File.exists?(@directory)
      FileUtils.mkdir(@directory)
    end

    @directory
  end

  def inline(*args, &block)
    if self == Class
      instance_inline(*args, &block)
    else
      singleton_inline(*args, &block)
    end
  end

  def singleton_inline(*args)
    language = args.first.is_a?(Symbol) ? args.shift : :c
    code     = args.first.is_a?(String) ? args.shift : ''
    options  = args.first.is_a?(Hash)   ? args.shift : {}

    builder = Builder[language].new(code, options)
    yield builder if block_given?
    mod = builder.build

    builder.symbols.each {|sym|
      define_singleton_method sym, &mod.method(sym)
    }
  end

  def instance_inline(*args)
    language = args.first.is_a?(Symbol) ? args.shift : :c
    code     = args.first.is_a?(String) ? args.shift : ''
    options  = args.first.is_a?(Hash)   ? args.shift : {}

    builder = Builder[language].new(code, options)
    yield builder if block_given?
    mod = builder.build

    builder.symbols.each {|sym|
      define_method sym, &mod.method(sym)
    }
  end
end

end

require 'ffi/inliner/compilers'
require 'ffi/inliner/builders'
