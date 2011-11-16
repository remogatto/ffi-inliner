module FFI; module Inliner

Compiler.define Compiler[:gcc], :gxx, 'g++' do
  def exists?
    `g++ -v 2>&1'`; $?.success?
  end

  def input
    File.join(Inliner.directory, "#{digest}.cpp").tap {|path|
      File.open(path, 'w') { |f| f.write(@code) } unless File.exists?(path)
    }
  end

  def ldshared
    if RbConfig::CONFIG['target_os'] =~ /darwin/
      "g++ -dynamic -bundle -fPIC #{options}"
    else
      "g++ -shared -fPIC #{options}"
    end
  end
end

end; end
