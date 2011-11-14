module FFI; module Inliner; module Compilers

class GXX < GCC
  def self.exists?
    !!::IO.popen('g++ 2>&1') { |f| f.read(1) }
  end

  def initialize (code, libraries = [])
    super('g++')

    @code      = code
    @libraries = libraries
  end

  def input
    File.join(Inliner.directory, "#{digest}.cpp").tap {|path|
      File.open(path, 'w') { |f| f.write(@code) }
    }
  end

  def ldshared
    if RbConfig::CONFIG['target_os'] =~ /darwin/
      'g++ -dynamic -bundle -fPIC'
    else
      'g++ -shared -fPIC'
    end
  end
end

end; end; end
