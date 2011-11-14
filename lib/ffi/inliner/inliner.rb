module FFI

module Inliner
  NULL = case RbConfig::CONFIG['target_os']
    when /mswin|mingw/ then 'nul'
    else                    '/dev/null'
    end

  LIB_EXT = case RbConfig::CONFIG['target_os']
    when /darwin/      then '.dylib'
    when /mswin|mingw/ then '.dll'
    else                    '.so'
    end

  C_TO_FFI = {
    'void'          => :void,
    'char'          => :char,
    'unsigned char' => :uchar,
    'int'           => :int,
    'unsigned int'  => :uint,
    'long'          => :long,
    'unsigned long' => :ulong,
    'float'         => :float,
    'double'        => :double,
  }

  def self.directory
    @directory ||= File.expand_path(File.join('~', '.ffi-inliner'))

    if File.exists?(@directory) && !File.directory?(@directory)
      FileUtils.rm_rf @directory
    end

    if !File.exists?(@directory)
      FileUtils.mkdir(@directory)
    end

    @directory
  end

  def inline(code = "", options = {})
    builder = Builder.new(self, code, options)
    yield builder if block_given?
    builder.build
  end
end

end

require 'ffi/inliner/file_manager'
require 'ffi/inliner/compilers'
require 'ffi/inliner/builder'
