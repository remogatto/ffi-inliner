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

  def inline(*args)
    language = args.first.is_a?(Symbol) ? args.shift : :c
    code     = args.first.is_a?(String) ? args.shift : ''
    options  = args.first.is_a?(Hash)   ? args.shift : {}

    builder = Builder.const_get(language.capitalize).new(self, code, options)
    yield builder if block_given?
    builder.build
  end
end

end

require 'ffi/inliner/builders'
require 'ffi/inliner/compilers'
