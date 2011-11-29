require 'ffi/inliner/error'

module FFI

module Inliner
  def self.directory
    if ENV['FFI_INLINER_PATH'] && !ENV['FFI_INLINER_PATH'].empty?
      @directory = ENV['FFI_INLINER_PATH']
    else
      require 'tmpdir'
      @directory ||= File.expand_path(File.join(Dir.tmpdir, ".ffi-inliner-#{Process.uid}"))
    end

    if File.exists?(@directory) && !File.directory?(@directory)
      raise 'the FFI_INLINER_PATH exists and is not a directory'
    end

    if !File.exists?(@directory)
      FileUtils.mkdir(@directory)
    end

    @directory
  end

  def inline(*args, &block)
    if self.class == Class
      instance_inline(*args, &block)
    else
      singleton_inline(*args, &block)
    end
  end

  def singleton_inline(*args)
    language = (args.first.is_a?(Symbol) || block_given?) ? args.shift : :c
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
    language = (args.first.is_a?(Symbol) || block_given?) ? args.shift : :c
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
