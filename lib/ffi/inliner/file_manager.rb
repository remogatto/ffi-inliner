module FFI; module Inliner

class FileName
  def initialize(name)
    @name      = name.name.gsub(/[:#<>\/]/, '_')
    @code      = code
    @libraries = libraries
  end

  def cached?
    exists?
  end

  def exists?
    File.exists?(c_name)
  end

  def base_name
    File.join(Inliner.directory,
      "#{@name}_#{(Digest::SHA256.new << @code << @libraries.to_s).to_s[0 .. 10]}")
  end

  %w(rb log).each do |ext|
    define_method("#{ext}_name") { "#{base_name}.#{ext}" }
  end

  def so_name
    "#{base_name}#{LIB_EXT}"
  end
end

end; end
