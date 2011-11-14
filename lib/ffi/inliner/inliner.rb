module FFI

module Inliner
  NULL =
    if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
      'nul'
    else
      '/dev/null'
    end

  LIB_EXT =
    if RbConfig::CONFIG['target_os'] =~ /darwin/
      '.dylib'
    elsif RbConfig::CONFIG['target_os'] =~ /mswin|mingw/
      '.dll'
    else
      '.so'
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
    @directory ||= File.expand_path(File.join(Dir.tmpdir, ".ffi-inliner-#{Process.uid}"))

    if File.exists?(@directory) && !File.directory?(@directory)
      FileUtils.rm_rf @directory
    end

    if !File.exists?(@directory)
      FileUtils.mkdir(@directory)
    end
  end

  def inline(code = "", options = {})
    builder = Builder.new(self, code, options)
    yield builder if block_given?
    builder.build
  end
end

end

require 'ffi/inline/file_manager'
require 'ffi/inline/compilers'
require 'ffi/inline/builder'
