module FFI; module Inliner; module Compilers

class GXX < GCC
  def function(code)
    %{extern "C" {
      #{code}
    }}
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
