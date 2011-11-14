module FFI; module Inliner

class FileManager
  def initialize(name, code, libraries)
    @name       = name.name.gsub(/[:#<>\/]/, '_')
    @code      = code
    @libraries = libraries
  end

  def cached?
    exists?
  end

  def exists?
    File.exists?(c_fn)
  end

  def base_fn
    File.join(Inliner.directory, "#{@name}_#{Digest::SHA256.hexdigest(@code << @libraries.to_s)}")
  end

  %w(c rb log).each do |ext|
    define_method("#{ext}_fn") { "#{base_fn}.#{ext}" }
  end

  def so_fn
    "#{base_fn}#{LIB_EXT}"
  end
end

end; end
