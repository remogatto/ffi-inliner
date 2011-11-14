module FFI; module Inliner

class Compiler
  LIB_EXT = case RbConfig::CONFIG['target_os']
    when /darwin/      then '.dylib'
    when /mswin|mingw/ then '.dll'
    else                    '.so'
    end

  attr_reader :name

  def self.new (*args, &block)
    unless exists?
      raise "can't find compiler #{self.class}"
    end

    super(*args, &block)
  end

  def initialize(name)
    @name = name
  end

  def compile
    raise 'the Compiler has not been specialized'
  end
end

end; end
