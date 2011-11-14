require 'ffi/inliner/builders/c'
require 'ffi/inliner/compilers/gxx'

module FFI; module Inliner; module Builders

class CXX < C
  Compilers = {
    :gxx => Compilers::GXX
  }

  def function(code)
    @signatures << parse_signature(code)

    raw 'extern "C" {' << code << '}'
  end
end

end; end; end
